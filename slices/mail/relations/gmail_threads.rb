# frozen_string_literal: true

module Mail
  module Relations
    class GmailThreads < Blog::DB::Relation
      SPAM = Blog::Types::MessageStatus["spam"]
      LABELED = %i[status starred archived trashed sent draft important category].freeze
      SYNCED = [:subject, *LABELED, :received_at].freeze

      schema :mail_threads, as: :gmail_threads, infer: true

      def relabel(row, now)
        row = row.slice(*LABELED)
        marked_spam_at = Sequel.function(:coalesce, :marked_spam_at, now) if row[:status] == SPAM
        changed = Sequel.is_distinct_from(row.keys.map { self[it].qualified }, row.values)

        where(changed).update(**row, marked_spam_at:, updated_at: now)
      end

      def restate(message, now)
        received_at = Sequel.function(:greatest, :received_at, message[:received_at])

        update(received_at:, subject: Sequel.case([[{ draft: true }, message[:subject]]], :subject), updated_at: now)
      end

      def store(row)
        update = { **excluded([*SYNCED, :updated_at]), marked_spam_at: }

        dataset.returning(:id).insert_conflict(
          target: %i[mail_account_id gmail_id], update:, update_where: changed(SYNCED),
        ).insert(row)
      end

      private

      def marked_spam_at
        kept = Sequel.function(:coalesce, self[:marked_spam_at].qualified, Sequel[:excluded][:marked_spam_at])

        Sequel.case([[{ Sequel[:excluded][:status] => SPAM }, kept]], nil)
      end
    end
  end
end
