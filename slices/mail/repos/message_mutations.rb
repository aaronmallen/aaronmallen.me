# frozen_string_literal: true

module Mail
  module Repos
    class MessageMutations < Blog::DB::Repo
      SPAM = Blog::Types::MessageStatus["spam"]
      UNREAD = Blog::Types::MessageStatus["unread"]

      root :mail_threads

      stamped_commands :create, :update
      commands delete: :by_pk

      def claim(visitor_hashes:, limit:, total_limit:, since:, reply_to:, body:, subject:, status: UNREAD)
        fresh = mail_messages.from_visitors.received_since(since)

        mail_messages.capped_claim(fresh, visitor_hashes:, limit:, total_limit:) do
          thread = mail_threads.stamped(:create, :received_at).call(
            mail_account_id: mail_accounts.contact_form_id, subject:, status:,
            marked_spam_at: spam_marked_at(status, Time.now),
          )
          mail_messages.stamped(:create).call(
            mail_thread_id: thread.id, reply_to:, subject:, body:, visitor_hash: visitor_hashes.first,
            received_at: thread.received_at,
          )
          thread
        end
      end

      def delete_spam_marked_before(time) = mail_threads.marked_spam_before(time).delete

      def mark(thread, status, at: Time.now)
        transaction do
          status == SPAM ? spam_senders.flag(thread.reply_to, at:) : spam_senders.by_reply_to(thread.reply_to).delete
          update(thread.id, status:, marked_spam_at: spam_marked_at(status, thread.marked_spam_at || at))
        end
      end

      def snooze(id, ends_at) = update(id, snoozed_until: ends_at)

      private

      def spam_marked_at(status, at) = (at if status == SPAM)
    end
  end
end
