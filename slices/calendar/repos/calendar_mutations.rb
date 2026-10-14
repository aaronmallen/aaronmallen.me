# frozen_string_literal: true

module Calendar
  module Repos
    class CalendarMutations < Blog::DB::Repo
      def forget_accounts_but(accounts) = calendars.exclude(account: accounts).delete

      def move_event(id, times) = calendar_events.by_pk(id).update(**times, updated_at: Time.now)

      def show(ids) = calendars.update(hidden: Sequel.~(id: ids), updated_at: Time.now)

      def store(account, found, from:, to:, now: Time.now)
        transaction do
          ids = calendars.store(account, found.map { it.except(:events, :cancelled, :full) }, now:)
          calendars.where(account:).exclude(google_id: ids.keys).delete
          found.sum { store_events(ids.fetch(it[:google_id]), it, from, to, now) }
        end
      end

      private

      def stale(calendar_id, found, from, to)
        held = calendar_events.where(calendar_id:)
        return held.where(google_id: found[:cancelled]) unless found[:full]

        held.between(from, to).exclude(google_id: found[:events].map { it[:google_id] })
      end

      def store_events(calendar_id, found, from, to, now)
        calendar_events.store(found[:events].map { it.merge(calendar_id:) }, now:)
        stale(calendar_id, found, from, to).delete
        found[:events].size
      end
    end
  end
end
