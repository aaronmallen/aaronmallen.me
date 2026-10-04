# frozen_string_literal: true

module Analytics
  module Relations
    class AnalyticsClicks < Blog::DB::Relation
      TABLE_KEY = Sequel.function(:hashtext, "analytics_clicks")

      schema :analytics_clicks, infer: true

      def claim(event_id:, limit:, **link)
        transaction do
          lock_until_commit(event_id)
          next unless for_event(event_id).count < limit

          stamped(:create).call(event_id:, **link)
        end
      end

      def for_event(event_id) = where(event_id:)

      private

      def lock_until_commit(event_id) = dataset.db.get(Sequel.function(:pg_advisory_xact_lock, TABLE_KEY, event_id))
    end
  end
end
