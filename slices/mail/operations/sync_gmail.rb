# frozen_string_literal: true

require "sanitize"

module Mail
  module Operations
    class SyncGmail < Blog::Operation
      BACKFILL_STALLED_AFTER = 60 * 60
      PAGE_SIZE = 25
      SCOPE = "https://www.googleapis.com/auth/gmail.modify"
      SETTINGS_EVERY = 3600

      include Deps[
        "settings",
        google: "google.client",
        gmail_backfills: "repos.gmail_backfills",
        gmail_mutations: "repos.gmail_mutations",
        gmail_queries: "repos.gmail_queries",
        honeybadger: "honeybadger.agent",
        parse_gmail_thread: "operations.parse_gmail_thread",
      ]

      def backfill(address, page_token = nil)
        mailbox = mailbox(address)
        account = gmail_mutations.account(address)
        page = threads(mailbox, page_token)
        page.fetch("threads", []).each { store(mailbox, account.id, it.fetch("id")) }

        Success(page["nextPageToken"])
      rescue Google::RateLimited => e
        Failure([:gmail_rate_limited, e.message])
      rescue Google::Error => e
        Failure([:gmail_failed, e.message])
      end

      def call = step synced

      private

      def catch_up(mailbox, account)
        records, history_id = changes(mailbox, account.history_id)
        history = Structs::GmailHistory.new(records)
        refresh(mailbox, account.id) if stale?(account, history)
        ids = store_all(mailbox, account, history)
        gmail_mutations.follow(account.id, history_id) unless history_id == account.history_id
        ids.size
      rescue Google::NotFound
        start(mailbox, account)
      end

      def changes(mailbox, start)
        found = mailbox.pages("history", rows: "history", startHistoryId: start)
        [found["history"], found["nextPageToken"] ? found["history"].dig(-1, "id") || start : found["historyId"]]
      end

      def mailbox(address, client = google.loaded) = Mailbox.new(client, address)

      def refresh(mailbox, account_id)
        gmail_mutations.store_labels(account_id, mailbox.user_labels)
        gmail_mutations.sign(account_id, Sanitize.fragment(mailbox.signature, ParseGmailThread::SANITIZE).strip)
      end

      def relabeled?(mailbox, account_id, gmail_id)
        gmail_mutations.relabel(account_id, parse_gmail_thread.call(mailbox.thread(gmail_id, format: "minimal")))
      end

      def resume_stalled_backfills(addresses)
        gmail_backfills.resume(Time.now - BACKFILL_STALLED_AFTER, addresses).each { Jobs::BackfillGmail.perform_async(*it) }
      end

      def stale?(account, history)
        return true if account.settings_synced_at.nil? || account.settings_synced_at < Time.now - SETTINGS_EVERY

        labels = history.added_user_labels
        labels.any? && (labels - gmail_queries.label_ids(account.id)).any?
      end

      def start(mailbox, account)
        refresh(mailbox, account.id)
        gmail_mutations.follow(account.id, mailbox.get("profile").fetch("historyId"))
        gmail_backfills.hold(mailbox.address, nil)
        Jobs::BackfillGmail.perform_async(mailbox.address)
        0
      end

      def store(mailbox, account_id, gmail_id, labels_only: false)
        return if labels_only && relabeled?(mailbox, account_id, gmail_id)

        thread = parse_gmail_thread.call(mailbox.thread(gmail_id))
        gmail_mutations.store_thread(account_id, thread)
      rescue Google::NotFound
        gmail_mutations.delete_thread(account_id, gmail_id)
      rescue ArgumentError, Sequel::DatabaseError => e
        honeybadger.notify(e, context: { mail_account_id: account_id, gmail_thread_id: gmail_id })
      end

      def store_all(mailbox, account, history)
        labeled = history.label_only_thread_ids
        history.thread_ids.each_with_object([]) do |id, stored|
          store(mailbox, account.id, id, labels_only: labeled.include?(id))
          stored << id
        rescue Google::RateLimited
          settled = history.settled_id(stored)
          gmail_mutations.follow(account.id, settled) if settled
          raise
        end
      end

      def sync(mailbox)
        account = gmail_mutations.account(mailbox.address)

        Success(account.history_id ? catch_up(mailbox, account) : start(mailbox, account))
      rescue Google::Error => e
        Failure([:gmail_failed, e.message])
      end

      def synced
        client = google.loaded
        addresses = client.holders(SCOPE)
        results = addresses.map { sync(mailbox(it, client)) }
        resume_stalled_backfills(addresses)
        results.find(&:failure?) || Success(results.sum(&:value!))
      end

      def threads(mailbox, page_token)
        mailbox.get("threads", includeSpamTrash: true, maxResults: PAGE_SIZE, q: window, **token(page_token))
      end

      def token(page_token) = page_token ? { pageToken: page_token } : {}

      def window
        days = settings.mail[:backfill_days]
        ["-in:trash", ("newer_than:#{days}d" if days)].compact.join(" ")
      end
    end
  end
end
