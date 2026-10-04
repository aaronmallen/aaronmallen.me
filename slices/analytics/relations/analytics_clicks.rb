# frozen_string_literal: true

module Analytics
  module Relations
    class AnalyticsClicks < Blog::DB::Relation
      schema :analytics_clicks, infer: true

      def claim(event_id:, limit:, **link)
        stamped(:create).call(event_id:, **link) if for_event(event_id).count < limit
      end

      def for_event(event_id) = where(event_id:)
    end
  end
end
