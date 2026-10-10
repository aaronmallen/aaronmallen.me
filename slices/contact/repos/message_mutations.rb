# frozen_string_literal: true

module Contact
  module Repos
    class MessageMutations < DB::Repo
      SPAM = Blog::Types::MessageStatus["spam"]
      UNREAD = Blog::Types::MessageStatus["unread"]

      root :messages

      stamped_commands :create, :update
      commands delete: :by_pk

      def claim(visitor_hashes:, limit:, total_limit:, since:, status: UNREAD, **attrs)
        marked_spam_at = spam_marked_at(status, Time.now)

        messages.claim(visitor_hashes:, limit:, total_limit:, since:, **attrs, status:, marked_spam_at:)
      end

      def delete_spam_marked_before(time) = messages.marked_spam_before(time).delete

      def mark(message, status, at: Time.now)
        transaction do
          status == SPAM ? spam_senders.flag(message.reply_to, at:) : spam_senders.by_reply_to(message.reply_to).delete
          update(message.id, status:, marked_spam_at: spam_marked_at(status, message.marked_spam_at || at))
        end
      end

      def snooze(id, ends_at) = update(id, snoozed_until: ends_at)

      private

      def spam_marked_at(status, at) = (at if status == SPAM)
    end
  end
end
