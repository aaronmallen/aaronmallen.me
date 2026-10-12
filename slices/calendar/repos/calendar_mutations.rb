# frozen_string_literal: true

module Calendar
  module Repos
    class CalendarMutations < Blog::DB::Repo
      def forget_accounts_but(accounts) = calendars.exclude(account: accounts).delete

      def show(ids) = calendars.update(hidden: Sequel.~(id: ids), updated_at: Time.now)

      def store(account, found, from:, to:, now: Time.now)
        transaction do
          ids = calendars.store(account, found.map { it.except(:events) }, now:)
          calendars.where(account:).exclude(google_id: ids.keys).delete
          found.sum { store_events(ids.fetch(it[:google_id]), it[:events], from, to, now) }
        end
      end

      private

      def store_events(calendar_id, events, from, to, now)
        calendar_events.store(events.map { it.merge(calendar_id:) }, now:)
        calendar_events.where(calendar_id:).between(from, to).exclude(google_id: events.map { it[:google_id] }).delete
        events.size
      end
    end
  end
end
