# frozen_string_literal: true

module Mail
  module Repos
    class MessageQueries < Blog::DB::Repo
      SETTINGS = {
        contact_form: true, people: true, needs_reply: true, starred: true, important: false, skip_notifications: true,
      }.freeze
      SETTINGS_ID = 1
      SPAM = Blog::Types::MessageStatus["spam"]
      UNREAD = Blog::Types::MessageStatus["unread"]

      def by_id(id) = mail_threads.with_letter.with_account.with_reason(settings).combine(:tags).by_pk(id).one

      def by_id_for_update(id) = mail_threads.by_pk(id).lock.one

      def count_from_visitor_since(visitor_hashes, time)
        mail_messages.for_visitor(visitor_hashes).received_since(time).count
      end

      def count_received_between(from:, to:) = in_days(from, to).tally(:status, Blog::Types::MessageStatus.values)

      def count_since(time) = mail_messages.from_visitors.received_since(time).count

      def count_with_status(status) = mail_threads.with_status(status).count

      def exist?(id) = mail_threads.by_pk(id).exist?

      def reasons(ids) = waiting.where(id: ids).to_a.to_h { [it.id, it.reason] }

      def received_between(from:, to:, page:, status: nil)
        found = in_days(from, to)
        found = found.with_status(status) if status

        page.fill(found.with_letter.with_account.combine(:tags).newest_first.paged(page).to_a)
      end

      def sender_status(reply_to) = spam_senders.by_reply_to(reply_to).exist? ? SPAM : UNREAD

      def settings = SETTINGS.merge(mail_settings.by_pk(SETTINGS_ID).one.to_h.slice(*SETTINGS.keys))

      def snoozed = waiting.asleep.with_letter.with_account.newest_first.to_a

      def thread(id)
        mail_threads.with_letter.with_account.combine(:tags, :mail_messages)
                    .node(:mail_messages) { it.order(:received_at, :id) }.by_pk(id).one
      end

      def unread = waiting.awake.with_letter.with_account.newest_first.to_a

      def unread_count = waiting.awake.count

      private

      def in_days(from, to)
        first, last = Blog::TimeZone.day_bounds(from, to)
        found = first ? mail_threads.received_since(first) : mail_threads
        last ? found.received_before(last) : found
      end

      def waiting = mail_threads.waiting(settings)
    end
  end
end
