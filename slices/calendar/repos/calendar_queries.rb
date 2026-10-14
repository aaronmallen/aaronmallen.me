# frozen_string_literal: true

module Calendar
  module Repos
    class CalendarQueries < Blog::DB::Repo
      def calendar(id) = calendars.by_pk(id).one

      def event(id) = calendar_events.by_pk(id).combine(:calendar).one

      def events_between(from:, to:, include_hidden: true)
        found = calendar_events.between(from, to)
        found = found.where(calendar_id: calendars.where(hidden: false).pluck(:id)) unless include_hidden

        found.in_day_order.combine(:calendar).to_a
      end

      def listed = calendars.in_list_order.to_a

      def sync_tokens(account) = calendars.where(account:).dataset.to_hash(:google_id, :sync_token)
    end
  end
end
