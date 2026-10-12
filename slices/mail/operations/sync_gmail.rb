# frozen_string_literal: true

require "sanitize"

module Mail
  module Operations
    class SyncGmail < Blog::Operation
      GMAIL = "https://gmail.googleapis.com/gmail/v1/users/me"
      PAGE_SIZE = 100
      SCOPE = "https://www.googleapis.com/auth/gmail.modify"
      USER_LABEL = "user"

      include Deps[google: "google.google.client", gmail_mutations: "repos.gmail_mutations"]

      def backfill(address, page_token = nil)
        account = gmail_mutations.account(address)
        page = gmail(address, "threads", includeSpamTrash: true, maxResults: PAGE_SIZE, **token(page_token))
        page.fetch("threads", []).each { store(address, account.id, it.fetch("id")) }

        Success(page["nextPageToken"])
      rescue Google::Error => e
        Failure([:gmail_failed, e.message])
      end

      def call = step synced

      private

      def catch_up(address, account)
        ids, history_id = changes(address, account.history_id)
        ids.uniq.each { store(address, account.id, it) }
        gmail_mutations.follow(account.id, history_id)
        ids.uniq.size
      rescue Google::NotFound
        start(address, account)
      end

      def changes(address, start, page_token = nil)
        page = gmail(address, "history", startHistoryId: start, **token(page_token))
        ids = page.fetch("history", []).flat_map { it.fetch("messages", []) }.map { it.fetch("threadId") }
        following = page["nextPageToken"]
        return [ids, page.fetch("historyId")] unless following

        more, last = changes(address, start, following)
        [ids + more, last]
      end

      def gmail(address, path, **) = google.get("#{GMAIL}/#{path}", account: address, **)

      def start(address, account)
        gmail_mutations.follow(account.id, gmail(address, "profile").fetch("historyId"))
        Jobs::BackfillGmail.perform_async(address)
        0
      end

      def store(address, account_id, gmail_id)
        gmail_mutations.store_thread(account_id, GmailThread.new(gmail(address, "threads/#{gmail_id}", format: "full")))
      rescue Google::NotFound
        gmail_mutations.delete_thread(account_id, gmail_id)
      end

      def store_labels(address, account_id)
        labels = gmail(address, "labels").fetch("labels", []).select { it["type"] == USER_LABEL }

        gmail_mutations.store_labels(account_id, labels.map { { gmail_id: it.fetch("id"), name: it.fetch("name") } })
      end

      def store_signature(address, account_id)
        signature = gmail(address, "settings/sendAs/#{address}")["signature"].to_s

        gmail_mutations.sign(account_id, Sanitize.fragment(signature, GmailThread::SANITIZE).strip)
      end

      def sync(address)
        account = gmail_mutations.account(address)
        store_labels(address, account.id)
        store_signature(address, account.id)

        account.history_id ? catch_up(address, account) : start(address, account)
      end

      def synced
        Success(google.holders(SCOPE).sum { sync(it) })
      rescue Google::Error => e
        Failure([:gmail_failed, e.message])
      end

      def token(page_token) = page_token ? { pageToken: page_token } : {}
    end
  end
end
