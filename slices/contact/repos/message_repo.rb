# frozen_string_literal: true

module Contact
  module Repos
    class MessageRepo < Blog::DB::Repo
      SPAM = Blog::Types::MessageStatus["spam"]
      UNREAD = Blog::Types::MessageStatus["unread"]

      commands :create, use: :timestamps, plugins_options: { timestamps: { timestamps: %i[created_at updated_at] } }
      commands update: :by_pk, use: :timestamps, plugins_options: { timestamps: { timestamps: %i[updated_at] } }

      def by_id(id) = messages.by_pk(id).one

      def by_status(status) = messages.with_status(status).newest_first.to_a

      def claim(visitor_hash:, limit:, since:, status: UNREAD, **attrs)
        marked_spam_at = spam_marked_at(status, Time.now)

        messages.claim(visitor_hash:, limit:, since:, **attrs, status:, marked_spam_at:)
      end

      def count_from_visitor_since(visitor_hash, time) = messages.for_visitor(visitor_hash).received_since(time).count

      def count_with_status(status) = messages.with_status(status).count

      def delete_spam_marked_before(time) = messages.marked_spam_before(time).delete

      def mark(message, status, at: Time.now)
        transaction do
          status == SPAM ? spam_senders.flag(message.reply_to, at:) : spam_senders.by_reply_to(message.reply_to).delete
          update(message.id, status:, marked_spam_at: spam_marked_at(status, message.marked_spam_at || at))
        end
      end

      def page_by_status(status, page) = page.fill(messages.with_status(status).newest_first.paged(page).to_a)

      def received_between(from:, to:, page:, status: nil)
        found = messages.received_since(Blog::TimeZone.day_start(from))
        found = found.received_before(Blog::TimeZone.day_start(to + 1))
        found = found.with_status(status) if status

        page.fill(found.newest_first.paged(page).to_a)
      end

      def sender_status(reply_to) = spam_senders.by_reply_to(reply_to).exist? ? SPAM : UNREAD

      private

      def spam_marked_at(status, at) = (at if status == SPAM)
    end
  end
end
