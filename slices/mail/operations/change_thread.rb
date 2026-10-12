# frozen_string_literal: true

module Mail
  module Operations
    class ChangeThread < Blog::Operation
      ACT = Blog::Types::MessageBulkAction
      STATUS = Blog::Types::MessageStatus
      THREADS = "#{SyncGmail::GMAIL}/threads".freeze
      UNSPAM = { addLabelIds: %w[INBOX], removeLabelIds: %w[SPAM] }.freeze
      LABELS = {
        ACT["archive"] => { removeLabelIds: %w[INBOX] },
        ACT["inbox"] => UNSPAM,
        ACT["read"] => { removeLabelIds: %w[UNREAD] },
        ACT["unread"] => { addLabelIds: %w[UNREAD] },
        ACT["spam"] => { addLabelIds: %w[SPAM], removeLabelIds: %w[INBOX] },
        ACT["star"] => { addLabelIds: %w[STARRED] },
        ACT["unstar"] => { removeLabelIds: %w[STARRED] },
      }.freeze
      COLUMNS = {
        ACT["archive"] => { archived: true },
        ACT["inbox"] => { archived: false, trashed: false, snoozed_until: nil },
        ACT["star"] => { starred: true },
        ACT["unstar"] => { starred: false },
        ACT["trash"] => { trashed: true },
      }.freeze

      include Deps[
        google: "google.google.client",
        gmail_mutations: "repos.gmail_mutations",
        message_mutations: "repos.message_mutations",
        message_queries: "repos.message_queries",
        message_tag_mutations: "repos.message_tag_mutations",
      ]

      def call(id, act, label: nil)
        thread = step found(message_queries.by_id(id))
        return labeled(thread, *label.split(":", 2)) if act == ACT["label"]

        step gmail(thread) { write(it, thread, act) }
        change(thread, act)
        message_queries.by_id(id)
      end

      private

      def change(thread, act)
        status = status(thread, act)
        spam = status == STATUS["spam"]
        columns = COLUMNS.fetch(act, {})
        columns = { archived: spam, **columns } if spam != (thread.status == STATUS["spam"])

        transaction do
          message_mutations.mark(thread, status) if status != thread.status
          message_mutations.update(thread.id, **columns) if columns.any?
        end
      end

      def gmail(thread)
        address = thread.gmail_id && gmail_mutations.address(thread.mail_account_id)
        yield(address) if address
        Success(thread)
      rescue Google::Error
        Failure(:gmail_failed)
      end

      def labeled(thread, account, name)
        return unless thread.mail_account_id == Integer(account)

        label = gmail_mutations.label_named(thread.mail_account_id, name)
        if label
          step gmail(thread) { post(it, thread, "modify", addLabelIds: [label.gmail_id]) }
          gmail_mutations.add_label(thread.id, label.id)
        else
          message_tag_mutations.add(thread.id, name)
        end
        message_queries.by_id(thread.id)
      end

      def labels(thread, act)
        labels = LABELS.fetch(act)
        return labels unless thread.status == STATUS["spam"] && [ACT["read"], ACT["unread"]].include?(act)

        labels.merge(UNSPAM) { |_key, mine, theirs| mine + theirs }
      end

      def post(address, thread, verb, body = {})
        google.post("#{THREADS}/#{thread.gmail_id}/#{verb}", body, account: address)
      end

      def status(thread, act)
        return act if STATUS.valid?(act)

        act == ACT["inbox"] && thread.status == STATUS["spam"] ? STATUS["read"] : thread.status
      end

      def write(address, thread, act)
        return post(address, thread, "trash") if act == ACT["trash"]

        post(address, thread, "untrash") if act == ACT["inbox"] && thread.trashed
        post(address, thread, "modify", labels(thread, act))
      end
    end
  end
end
