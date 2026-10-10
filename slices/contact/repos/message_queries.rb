# frozen_string_literal: true

module Contact
  module Repos
    class MessageQueries < Blog::DB::Repo
      INBOX = Blog::Types::MessageFilter["inbox"]
      NAME = Blog::DB::Plugins::Taggings::NAME
      SPAM = Blog::Types::MessageStatus["spam"]
      UNREAD = Blog::Types::MessageStatus["unread"]

      def by_id(id) = messages.combine(:tags).by_pk(id).one

      def count_from_visitor_since(visitor_hashes, time)
        messages.for_visitor(visitor_hashes).received_since(time).count
      end

      def count_listed(**) = listed(**).count

      def count_received_between(from:, to:)
        counted = in_days(from, to).counts_by(:status).to_a

        Blog::Types::MessageStatus.values.to_h { [it, 0] }.merge(counted.to_h { [it.status, it.count] })
      end

      def count_since(time) = messages.received_since(time).count

      def count_with_status(status) = messages.with_status(status).count

      def exist?(id) = messages.by_pk(id).exist?

      def page_listed(page, **) = page.fill(listed(**).combine(:tags).newest_first.paged(page).to_a)

      def received_between(from:, to:, page:, status: nil)
        found = in_days(from, to)
        found = found.with_status(status) if status

        page.fill(found.combine(:tags).newest_first.paged(page).to_a)
      end

      def sender_status(reply_to) = spam_senders.by_reply_to(reply_to).exist? ? SPAM : UNREAD

      def snoozed = messages.with_status(UNREAD).asleep.to_a

      def tag_names = message_tags.join(:tag).dataset.unordered.distinct.order(NAME).select_map(NAME)

      def unread = waiting.newest_first.to_a

      def unread_count = waiting.count

      private

      def in_days(from, to)
        first, last = Blog::TimeZone.day_bounds(from, to)
        found = first ? messages.received_since(first) : messages
        last ? found.received_before(last) : found
      end

      def listed(status:, search: nil, tag: nil)
        found = status == INBOX ? messages.exclude(status: SPAM) : messages.with_status(status)
        found = found.matching(search) if search
        tag ? found.tagged(tag) : found
      end

      def waiting = messages.with_status(UNREAD).awake
    end
  end
end
