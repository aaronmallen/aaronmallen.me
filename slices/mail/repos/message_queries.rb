# frozen_string_literal: true

module Mail
  module Repos
    class MessageQueries < Blog::DB::Repo
      INBOX = Blog::Types::MessageFilter["inbox"]
      NAME = Blog::DB::Plugins::Taggings::NAME
      SPAM = Blog::Types::MessageStatus["spam"]
      UNREAD = Blog::Types::MessageStatus["unread"]

      def by_id(id) = mail_threads.with_letter.combine(:tags).by_pk(id).one

      def count_from_visitor_since(visitor_hashes, time)
        mail_messages.for_visitor(visitor_hashes).received_since(time).count
      end

      def count_listed(**) = listed(**).count

      def count_received_between(from:, to:) = in_days(from, to).tally(:status, Blog::Types::MessageStatus.values)

      def count_since(time) = mail_messages.from_visitors.received_since(time).count

      def count_with_status(status) = mail_threads.with_status(status).count

      def exist?(id) = mail_threads.by_pk(id).exist?

      def page_listed(page, **) = page.fill(listed(**).with_letter.combine(:tags).newest_first.paged(page).to_a)

      def received_between(from:, to:, page:, status: nil)
        found = in_days(from, to)
        found = found.with_status(status) if status

        page.fill(found.with_letter.combine(:tags).newest_first.paged(page).to_a)
      end

      def sender_status(reply_to) = spam_senders.by_reply_to(reply_to).exist? ? SPAM : UNREAD

      def snoozed = mail_threads.with_status(UNREAD).asleep.with_letter.to_a

      def tag_names = mail_thread_tags.join(:tag).dataset.unordered.distinct.order(NAME).select_map(NAME)

      def unread = waiting.with_letter.newest_first.to_a

      def unread_count = waiting.count

      private

      def in_days(from, to)
        first, last = Blog::TimeZone.day_bounds(from, to)
        found = first ? mail_threads.received_since(first) : mail_threads
        last ? found.received_before(last) : found
      end

      def listed(status:, search: nil, tag: nil)
        found = status == INBOX ? mail_threads.exclude(status: SPAM) : mail_threads.with_status(status)
        found = found.matching(search) if search
        tag ? found.tagged(tag) : found
      end

      def waiting = mail_threads.with_status(UNREAD).awake
    end
  end
end
