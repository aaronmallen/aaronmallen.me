# frozen_string_literal: true

module Health
  module Relations
    class HealthDays < Blog::DB::Relation
      COLUMNS = %i[minutes_asleep bed_at woke_at resting_heart_rate hrv steps active_zone_minutes updated_at].freeze
      COUNT = Sequel.function(:count).*
      DAY = Sequel[:days][:day]
      ENDED = Sequel.function(:coalesce, :ended_at, Sequel::CURRENT_TIMESTAMP)
      ZONE = Blog::TimeZone::NAME
      ACTIVE = %i[first_active_at last_active_at].map { Sequel[:active][it] }.freeze
      LATE = COUNT.filter(Sequel[:commit_time] >= Sequel.cast("22:00", :time)).as(:late_commits)
      COMMITS = [Sequel[:commit_date].as(:day), COUNT.as(:commits), LATE].freeze
      COMMIT_AT = Sequel.function(:timezone, ZONE, Sequel[:commit_date] + Sequel[:commit_time])
      DAY_END = day_end(DAY)
      DAY_START = day_start(DAY)
      DONE = { status: Blog::Types::TaskStatus["done"] }.freeze
      FIGURES = {
        worked: %i[focus_minutes], commits: %i[commits late_commits], done: %i[tasks_done],
        opened: %i[pull_requests_opened], merged: %i[pull_requests_merged], journal: %i[journal_entries],
      }.flat_map { |table, names| names.map { Sequel.function(:coalesce, Sequel[table][it], 0).as(it) } }.freeze
      FOCUS_MINUTES = (Sequel.function(:sum, :seconds) / 60).cast(Integer).as(:focus_minutes)
      JOURNAL = [Sequel[:entry_date].as(:day), COUNT.as(:journal_entries)].freeze
      HEALTH = (COLUMNS - %i[updated_at]).map { Sequel[:health_days][it] }.freeze
      OVERLAP = (Sequel[:started_at] < DAY_END) & (Sequel.expr(ENDED) > DAY_START)
      SPAN = [
        DAY, Sequel.function(:greatest, :started_at, DAY_START), Sequel.function(:least, ENDED, DAY_END),
      ].freeze
      FIRST_ACTIVE = Sequel.function(:min, :first_at).as(:first_active_at)
      LAST_ACTIVE = Sequel.function(:max, :last_at).as(:last_active_at)
      WORKED = [Sequel[:worked_on].as(:day), FOCUS_MINUTES].freeze

      schema :health_days, infer: true

      def averages_between(first, last, columns)
        where(day: first..last).dataset.unordered.select(*columns.map { Sequel.function(:avg, it).as(it) }).first
      end

      def store(rows, now:)
        rows = rows.map { it.merge(created_at: now, updated_at: now) }

        dataset.insert_conflict(target: :day, update: excluded(COLUMNS)).multi_insert(rows)
      end

      def with_work(first, last)
        range = first..last
        found = figures(range).reduce(days(range).left_join(:health_days, day: DAY)) do |joined, (name, sub)|
          joined.left_join(sub.as(name), day: DAY)
        end

        found.select(DAY, *HEALTH, *FIGURES, *ACTIVE).order(DAY).to_a
      end

      private

      def activity(range)
        commits = db[:commits].where(commit_date: range).select(Sequel[:commit_date].as(:day), COMMIT_AT, COMMIT_AT)
        points = commits.union(sessions(range), all: true, from_self: false)

        db.from(points.as(:points, %i[day first_at last_at])).group(:day).select(:day, FIRST_ACTIVE, LAST_ACTIVE)
      end

      def counted(table, column, name, range, **where)
        day = self.class.site_day(column)

        within(db[table].where(where), column, range).group(day).select(day.as(:day), COUNT.as(name))
      end

      def dated(table, column, range) = db[table].where(column => range).group(column)

      def days(range)
        series = self.class.day_series(*range.minmax)

        db.from(series.as(:series, [:at])).select(Sequel[:at].cast(Date).as(:day)).from_self(alias: :days)
      end

      def db = dataset.db

      def figures(range)
        {
          worked: dated(:work_session_days, :worked_on, range).select(*WORKED),
          commits: dated(:commits, :commit_date, range).select(*COMMITS),
          done: counted(:tasks, :completed_at, :tasks_done, range, **DONE),
          opened: counted(:pull_requests, :ready_at, :pull_requests_opened, range),
          merged: counted(:pull_requests, :merged_at, :pull_requests_merged, range),
          journal: dated(:journal_entries, :entry_date, range).select(*JOURNAL),
          active: activity(range),
        }
      end

      def sessions(range)
        found = days(range).join(:work_sessions, OVERLAP)

        within(found, :started_at, range, ended: ENDED).select(*SPAN)
      end

      def within(found, column, range, ended: column)
        from, to = Blog::TimeZone.day_bounds(range.begin, range.end)

        found.where(Sequel[column] < to).where(Sequel.expr(ended) >= from)
      end
    end
  end
end
