# frozen_string_literal: true

module Tasks
  module Relations
    class WorkSessions < Blog::DB::Relation
      CLOSED_TASK = { Sequel[:tasks][:id] => Sequel[:closed][:task_id] }.freeze
      DAY = Sequel[:days][:day]
      ENDED = Sequel.function(:coalesce, :ended_at, Sequel::CURRENT_TIMESTAMP)
      ONE_DAY = Sequel.cast("1 day", :interval)
      SPAN_ORDER = { partition: :key, order: %i[started_at ended_at] }.freeze
      ROWS_BEFORE = { type: :rows, start: :preceding, end: [1, :preceding] }.freeze
      LATEST = Sequel.function(:max, :ended_at).over(**SPAN_ORDER, frame: ROWS_BEFORE)
      FRESH = Sequel.case([[Sequel[:started_at] <= LATEST, 0]], 1).as(:fresh)
      ISLAND = Sequel.function(:sum, :fresh).over(**SPAN_ORDER).as(:island)
      MERGED = [
        :key, Sequel.function(:min, :started_at).as(:started_at), Sequel.function(:max, :ended_at).as(:ended_at),
      ].freeze
      SESSION = Sequel.function(:floor, Sequel.extract(:epoch, Sequel[:ended_at] - Sequel[:started_at]))
      ZONE = Blog::TimeZone::NAME
      WORKED = Sequel[:tasks][:worked_seconds] + Sequel[:closed][:seconds]

      schema :work_sessions, infer: true do
        associations do
          belongs_to :task
        end
      end

      def close(task_ids, at)
        closed = tasks.dataset.unordered.with(:closed, ending(task_ids, at)).from(:tasks, :closed)

        closed.where(CLOSED_TASK).update(worked_seconds: WORKED)
      end

      def for_task(task_id) = where(task_id:)

      def merged_seconds_by_day(first, last, task_ids_by_key)
        names = task_ids_by_key.keys
        pairs = task_ids_by_key.values.each_with_index.flat_map { |ids, index| ids.map { [index, it] } }
        return {} if pairs.empty?

        found = merged_by_day(first, last, pairs).group_by(&:first)
        found.to_h { |index, rows| [names[index], rows.to_h { it.drop(1) }] }
      end

      def open(task_id, at) = running.for_task(task_id).exist? || command(:create).call(task_id:, started_at: at)

      def running = where(ended_at: nil)

      def seconds_by_day(first, last)
        found = by_day(overlapping(first, last).dataset.unordered, first, last)

        found.group(:task_id, DAY).select_map([:task_id, *day_columns])
      end

      def split(task_ids, at)
        close(task_ids, at)
        command(:create, result: :many).call(task_ids.map { { task_id: it, started_at: at } })
      end

      def totals_by_task
        dataset.unordered.group(:task_id).select(
          :task_id, Sequel.function(:sum, SESSION).as(:seconds), Sequel.function(:max, ENDED).as(:last_at),
        )
      end

      private

      def by_day(found, first, last) = found.cross_join(days(first, last).lateral.as(:days, [:day]))

      def clipped(first, last)
        [
          Sequel.function(:greatest, :started_at, Blog::TimeZone.day_start(first)).as(:started_at),
          Sequel.function(:least, ENDED, Blog::TimeZone.day_start(last + 1)).as(:ended_at),
        ]
      end

      def day_columns
        ends = Sequel.function(:least, ENDED, local(DAY + ONE_DAY))
        span = ends - Sequel.function(:greatest, :started_at, local(DAY))
        seconds = Sequel.function(:sum, Sequel.function(:floor, Sequel.extract(:epoch, span))).cast(Integer)

        [DAY.cast(Date).as(:worked_on), seconds.as(:seconds)]
      end

      def days(first, last)
        from = Sequel.function(:greatest, self.class.site_day(:started_at), first).cast(:timestamp)
        to = Sequel.function(:least, self.class.site_day(ENDED), last).cast(:timestamp)

        Sequel.function(:generate_series, from, to, ONE_DAY)
      end

      def db = dataset.db

      def ending(task_ids, at)
        ended = Sequel.function(:greatest, at, :started_at)

        found = running.where(task_id: task_ids).dataset.unordered.returning(:task_id, seconds(ended).as(:seconds))

        found.with_sql(:update_sql, ended_at: ended, updated_at: Sequel::CURRENT_TIMESTAMP)
      end

      def islands(spans)
        marked = db.from(spans.as(:spans)).select(:key, :started_at, :ended_at, FRESH)

        db.from(marked.as(:marked)).select(:key, :started_at, :ended_at, ISLAND)
      end

      def local(day) = Sequel.function(:timezone, ZONE, day)

      def merged_by_day(first, last, pairs)
        merged = db.from(islands(spans(first, last, pairs)).as(:islands)).group(:key, :island).select(*MERGED)

        by_day(db.from(merged.as(:merged)), first, last).group(:key, DAY).select_map([:key, *day_columns])
      end

      def overlapping(first, last)
        where(Sequel[:started_at] < Blog::TimeZone.day_start(last + 1))
          .where(Sequel.expr(ENDED) > Blog::TimeZone.day_start(first))
      end

      def seconds(ended) = Sequel.function(:floor, Sequel.extract(:epoch, ended - :started_at)).cast(Integer)

      def spans(first, last, pairs)
        keyed = Sequel.as(db.values(pairs), :keys, %i[key task_id])
        found = overlapping(first, last).dataset.unordered.join(keyed, task_id: Sequel[:work_sessions][:task_id])

        found.select(Sequel[:keys][:key], *clipped(first, last))
      end
    end
  end
end
