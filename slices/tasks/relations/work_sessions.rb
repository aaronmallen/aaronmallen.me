# frozen_string_literal: true

module Tasks
  module Relations
    class WorkSessions < Blog::DB::Relation
      CLOSED_TASK = { Sequel[:tasks][:id] => Sequel[:closed][:task_id] }.freeze
      DAY = Sequel[:days][:day]
      ENDED = Sequel.function(:coalesce, :ended_at, Sequel::CURRENT_TIMESTAMP)
      ONE_DAY = Sequel.cast("1 day", :interval)
      RUNNING = Sequel.expr(ended_at: nil)
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

      def closed_seconds_by_task(task_ids)
        closed = exclude(ended_at: nil).where(task_id: task_ids).dataset.unordered

        closed.group(:task_id).select_hash(:task_id, Sequel.function(:sum, SESSION).cast(Integer).as(:seconds))
      end

      def for_task(task_id) = where(task_id:)

      def open(task_id, at) = running.for_task(task_id).exist? || command(:create).call(task_id:, started_at: at)

      def running = where(ended_at: nil)

      def seconds_by_day(first, last)
        found = overlapping(first, last).dataset.unordered.cross_join(days(first, last).lateral.as(:days, [:day]))

        found.group(:task_id, DAY, RUNNING).select(*day_columns).to_a
      end

      def split(task_ids, at)
        close(task_ids, at)
        command(:create, result: :many).call(task_ids.map { { task_id: it, started_at: at } })
      end

      private

      def day_columns
        ends = Sequel.function(:least, ENDED, local(DAY + ONE_DAY))
        span = ends - Sequel.function(:greatest, :started_at, local(DAY))
        seconds = Sequel.function(:sum, Sequel.function(:floor, Sequel.extract(:epoch, span))).cast(Integer)

        [:task_id, DAY.cast(Date).as(:worked_on), RUNNING.as(:running), seconds.as(:seconds)]
      end

      def days(first, last)
        from = Sequel.function(:greatest, self.class.site_day(:started_at), first).cast(:timestamp)
        to = Sequel.function(:least, self.class.site_day(ENDED), last).cast(:timestamp)

        Sequel.function(:generate_series, from, to, ONE_DAY)
      end

      def ending(task_ids, at)
        ended = Sequel.function(:greatest, at, :started_at)

        found = running.where(task_id: task_ids).dataset.unordered.returning(:task_id, seconds(ended).as(:seconds))

        found.with_sql(:update_sql, ended_at: ended, updated_at: Sequel::CURRENT_TIMESTAMP)
      end

      def local(day) = Sequel.function(:timezone, ZONE, day)

      def overlapping(first, last)
        where(Sequel[:started_at] < Blog::TimeZone.day_start(last + 1))
          .where(Sequel.expr(ENDED) > Blog::TimeZone.day_start(first))
      end

      def seconds(ended) = Sequel.function(:floor, Sequel.extract(:epoch, ended - :started_at)).cast(Integer)
    end
  end
end
