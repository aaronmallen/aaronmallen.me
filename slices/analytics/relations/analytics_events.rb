# frozen_string_literal: true

module Analytics
  module Relations
    class AnalyticsEvents < Blog::DB::Relation
      LATEST_TITLE = proc { string.array_agg(title).order(NEWEST_FIRST).filter(TITLED).sql_subscript(1).as(:title) }
      NEWEST_FIRST = Sequel.desc(:occurred_at)
      SINGLE_VIEW = Sequel.expr(Sequel.function(:count).* => 1)
      TABLE_KEY = Sequel.function(:hashtext, "analytics_events")
      TITLED = Sequel.~(title: nil)
      TOTALS = proc do
        [
          integer.count(id).as(:views),
          integer.count(visitor_hash).distinct.as(:visitors),
          integer.coalesce(integer.sum(read_seconds), 0).as(:read_seconds),
        ]
      end

      schema :analytics_events, infer: true

      def claim(address_hash:, limit:, since:, **attrs)
        transaction do
          lock_until_commit(address_hash)
          next unless from_address(address_hash).since(since).count < limit

          stamped(:create).call(**attrs, address_hash:)
        end
      end

      def counts_by(column, as: column)
        unordered.select(self[column].as(as)) { integer.count(id).as(:views) }.group(column)
      end

      def for_view(view_token) = where(view_token:)

      def for_visitor(visitor_hash) = where(visitor_hash:)

      def from_address(address_hash) = where(address_hash:)

      def newest_first = order(self[:occurred_at].desc, self[:id].desc)

      def occurred_before(time) = where { occurred_at < time }

      def oldest_occurred_at = unordered.dataset.min(:occurred_at)

      def on_day(day) = since(Blog::TimeZone.day_start(day)).occurred_before(Blog::TimeZone.day_start(day + 1))

      def paths
        bouncers = bounced
        figures = unordered.select(:path, &LATEST_TITLE).select_append(&TOTALS)

        figures.select_append { integer.count(id).filter(visitor_hash: bouncers).as(:bounces) }.group(:path)
      end

      def record_read_seconds(read_seconds)
        newest = newest_first.limit(1).dataset.select(:id)
        raised = Sequel.function(:greatest, :read_seconds, read_seconds)

        unordered.where(id: newest).stamped(:update, result: :many).call(read_seconds: raised).size
      end

      def since(time) = where { occurred_at >= time }

      def totals = unordered.select(&TOTALS)

      private

      def bounced = unordered.dataset.select(:visitor_hash).group(:visitor_hash).having(SINGLE_VIEW)

      def lock_until_commit(address_hash)
        dataset.db.get(Sequel.function(:pg_advisory_xact_lock, TABLE_KEY, Sequel.function(:hashtext, address_hash)))
      end
    end
  end
end
