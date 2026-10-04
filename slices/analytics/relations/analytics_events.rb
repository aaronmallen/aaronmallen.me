# frozen_string_literal: true

module Analytics
  module Relations
    class AnalyticsEvents < Blog::DB::Relation
      CLICK = Sequel[:analytics_clicks]
      CLICKED = [Sequel[:analytics_events][:path], CLICK[:link_host], CLICK[:link_path]].freeze
      CLICKS = proc do
        [*CLICKED.map { string(it).as(it.column) }, integer.count(CLICK[:id]).as(:clicks)]
      end
      HOUR = Sequel.function(:date_trunc, "hour", :occurred_at, Blog::TimeZone::NAME)
      HOURLY = proc do
        [
          time.date_trunc("hour", occurred_at, Blog::TimeZone::NAME).as(:hour),
          integer.count(id).as(:views),
          integer.count(visitor_hash).distinct.as(:visitors),
        ]
      end
      LATEST_TITLE = proc { string.array_agg(title).order(NEWEST_FIRST).filter(TITLED).sql_subscript(1).as(:title) }
      MEDIAN_READ = Sequel.function(:percentile_cont, 0.5).within_group(:read_seconds)
      NEWEST_FIRST = Sequel.desc(:occurred_at)
      REACH = Sequel.function(:count, :month_visitor_hash).distinct
      READ_THROUGH = Sequel.&(
        Sequel[:scroll_depth] >= ReadThrough::SCROLL_DEPTH,
        Sequel[:read_seconds] >= ReadThrough::READ_SECONDS,
      )
      READ_THROUGHS = proc { integer.count(visitor_hash).distinct.filter(READ_THROUGH).as(:read_throughs) }
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
      VISITORS = Sequel.function(:count, :visitor_hash).distinct
      VISITS = Sequel.function(:count).*

      schema :analytics_events, infer: true

      def between(from, to) = since(from).occurred_before(to)

      def between_days(from, to) = between(Blog::TimeZone.day_start(from), Blog::TimeZone.day_start(to + 1))

      def claim(address_hash:, limit:, since:, **attrs)
        transaction do
          lock_until_commit(address_hash)
          next unless from_address(address_hash).since(since).count < limit

          stamped(:create).call(**attrs, address_hash:)
        end
      end

      def clicks
        joined = unordered.join(:analytics_clicks, event_id: :id)

        joined.select(&CLICKS).group(*CLICKED)
      end

      def counts_by(column, as: column)
        figures = unordered.select(self[column].as(as)) do
          [integer.count(id).as(:views), integer.count(visitor_hash).distinct.as(:visitors)]
        end

        figures.group(column)
      end

      def for_path(path) = where(path:)

      def for_view(view_token) = where(view_token:)

      def for_visitor(visitor_hash) = where(visitor_hash:)

      def from_address(address_hash) = where(address_hash:)

      def hourly = unordered.select(&HOURLY).group { HOUR }.order(:hour)

      def known(column) = exclude(column => nil)

      def newest_first = order(self[:occurred_at].desc, self[:id].desc)

      def newest_id = newest_first.limit(1).pluck(:id).first

      def occurred_before(time) = where { occurred_at < time }

      def oldest_occurred_at = unordered.dataset.min(:occurred_at)

      def on_day(day) = between_days(day, day)

      def page_counts_by(column, as: column) = counts_by(column, as:).select_append(:path).group_append(:path)

      def paths
        bouncers = bounced
        figures = unordered.select(:path, &LATEST_TITLE).select_append(&TOTALS)

        figures.select_append { integer.count(id).filter(visitor_hash: bouncers).as(:bounces) }.group(:path)
      end

      def reach = unordered.dataset.get(REACH)

      def reach_by_path = unordered.select(:path) { integer.count(month_visitor_hash).distinct.as(:reach) }.group(:path)

      def read_median = unordered.exclude(read_seconds: 0).dataset.get(MEDIAN_READ)

      def read_throughs_by_path = unordered.select(:path, &READ_THROUGHS).group(:path)

      def record_read_seconds(read_seconds) = raise_newest(:read_seconds, read_seconds)

      def record_scroll_depth(scroll_depth) = raise_newest(:scroll_depth, scroll_depth)

      def since(time) = where { occurred_at >= time }

      def totals = unordered.select(&TOTALS)

      def views_by_read_floor(floors)
        floor = Sequel.case(floors.reverse.map { [Sequel[:read_seconds] >= it, it] }, floors.first)

        unordered.dataset.group_and_count(floor.as(:floor)).to_h { [it.fetch(:floor), it.fetch(:count)] }
      end

      def visit_ends(direction)
        sequence = [Sequel.public_send(direction, :occurred_at), Sequel.public_send(direction, :id)]
        ends = unordered.dataset.distinct(:visitor_hash).select(:visitor_hash, :path).order(:visitor_hash, *sequence)

        dataset.db.from(ends).select(:path, VISITS.as(:visitors)).group(:path).order(Sequel.desc(:visitors), :path).to_a
      end

      def visitor_count = unordered.dataset.get(VISITORS)

      private

      def bounced = unordered.dataset.select(:visitor_hash).group(:visitor_hash).having(SINGLE_VIEW)

      def lock_until_commit(address_hash)
        dataset.db.get(Sequel.function(:pg_advisory_xact_lock, TABLE_KEY, Sequel.function(:hashtext, address_hash)))
      end

      def raise_newest(column, value)
        newest = newest_first.limit(1).dataset.select(:id)
        raised = Sequel.function(:greatest, column, value)

        unordered.where(id: newest).stamped(:update, result: :many).call(column => raised).size
      end
    end
  end
end
