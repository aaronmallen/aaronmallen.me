# frozen_string_literal: true

module Contact
  module Repos
    class MessageQueries < DB::Repo
      SPAM = Blog::Types::MessageStatus["spam"]
      UNREAD = Blog::Types::MessageStatus["unread"]

      def by_id(id) = messages.combine(:tags).by_pk(id).one

      def by_status(status) = messages.with_status(status).newest_first.to_a

      def count_from_visitor_since(visitor_hash, time) = messages.for_visitor(visitor_hash).received_since(time).count

      def count_received_between(from:, to:)
        counted = in_days(from, to).counts_by(:status).to_a

        Blog::Types::MessageStatus.values.to_h { [it, 0] }.merge(counted.to_h { [it.status, it.count] })
      end

      def count_since(time) = messages.received_since(time).count

      def count_with_status(status) = messages.with_status(status).count

      def exist?(id) = messages.by_pk(id).exist?

      def page_by_status(status, page)
        page.fill(messages.combine(:tags).with_status(status).newest_first.paged(page).to_a)
      end

      def received_between(from:, to:, page:, status: nil)
        found = in_days(from, to)
        found = found.with_status(status) if status

        page.fill(found.combine(:tags).newest_first.paged(page).to_a)
      end

      def sender_status(reply_to) = spam_senders.by_reply_to(reply_to).exist? ? SPAM : UNREAD

      def snoozed = messages.with_status(UNREAD).asleep.to_a

      def unread = waiting.newest_first.to_a

      def unread_count = waiting.count

      private

      def in_days(from, to)
        found = messages
        found = found.received_since(Blog::TimeZone.day_start(from)) if from
        to ? found.received_before(Blog::TimeZone.day_start(to + 1)) : found
      end

      def waiting = messages.with_status(UNREAD).awake
    end
  end
end
