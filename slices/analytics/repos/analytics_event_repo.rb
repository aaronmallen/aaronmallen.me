# frozen_string_literal: true

module Analytics
  module Repos
    class AnalyticsEventRepo < Blog::DB::Repo
      commands :create, use: :timestamps, plugins_options: { timestamps: { timestamps: %i[created_at updated_at] } }

      def claim(address_hash:, limit:, since:, **attrs)
        analytics_events.claim(address_hash:, limit:, since:, **attrs)
      end

      def count_from_address_since(address_hash, time) = analytics_events.from_address(address_hash).since(time).count

      def delete_before(time) = analytics_events.occurred_before(time).delete

      def oldest_day
        occurred_at = analytics_events.oldest_occurred_at
        Blog::TimeZone.today(occurred_at) if occurred_at
      end

      def record_read_seconds(visitor_hash:, view_token:, read_seconds:)
        analytics_events.for_visitor(visitor_hash).for_view(view_token).record_read_seconds(read_seconds)
      end

      def summary_for(day)
        window = analytics_events.on_day(day)

        Structs::AnalyticsSummary.new(
          day:,
          totals: window.totals.one,
          paths: window.paths.to_a,
          referrers: window.counts_by(:referrer_host, as: :host).to_a,
          countries: window.counts_by(:country_code).to_a,
        )
      end

      def visitors_on(day) = analytics_events.on_day(day).visitor_count
    end
  end
end
