# frozen_string_literal: true

module Analytics
  module Repos
    class AnalyticsEventMutations < Blog::DB::Repo
      root :analytics_events

      stamped_commands :create

      def claim(address_hashes:, limit:, since:, **attrs)
        analytics_events.claim(address_hashes:, limit:, since:, **attrs)
      end

      def delete_before(time) = analytics_events.occurred_before(time).delete

      def record_click(event_id:, limit:, link_host:, link_path:)
        analytics_clicks.claim(event_id:, limit:, link_host:, link_path:)
      end

      def record_read_seconds(visitor_hashes:, view_token:, read_seconds:)
        analytics_events.for_visitor(visitor_hashes).for_view(view_token).record_read_seconds(read_seconds)
      end

      def record_scroll_depth(visitor_hashes:, view_token:, scroll_depth:)
        analytics_events.for_visitor(visitor_hashes).for_view(view_token).record_scroll_depth(scroll_depth)
      end
    end
  end
end
