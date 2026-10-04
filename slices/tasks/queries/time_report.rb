# frozen_string_literal: true

module Tasks
  module Queries
    class TimeReport
      DAY = Blog::Types::TimeGrouping["day"]
      NONE = [nil].freeze
      PROJECT = Blog::Types::TimeGrouping["project"]

      include Deps[linkable_projects: "projects.queries.linkable_projects", time_report_repo: "repos.time_report_repo"]

      def call(from:, to:, by:)
        grouping = Blog::Types::TimeGrouping[by]
        tasks, pieces = worked(from, to)

        Structs::TimeReport.new(
          from:, to:, by: grouping, seconds: total(pieces), groups: groups(grouping, pieces, tasks),
        )
      end

      private

      def group(key, name, seconds_by_task, tasks, shared)
        found = task_times(seconds_by_task, tasks, shared)
        return if found.empty?

        Structs::TimeGroup.new(key:, name:, seconds: found.sum(&:seconds), shared: found.any?(&:shared), tasks: found)
      end

      def groups(grouping, pieces, tasks)
        sums = sums(keys_for(grouping, pieces.map(&:first).uniq), pieces)
        shared = grouping == DAY ? Set.new : shared_ids(sums)

        found = sums.filter_map { |(key, name), seconds_by_task| group(key, name, seconds_by_task, tasks, shared) }
        found.sort_by { [it.key.nil? ? 1 : 0, it.name.to_s] }
      end

      def keys_for(grouping, ids)
        case grouping
        when DAY then ->(_, day) { [[day, day.iso8601]] }
        when PROJECT then project_keys(ids)
        else tag_keys(ids)
        end
      end

      def project_keys(ids)
        project_ids = time_report_repo.project_ids(ids)
        names = linkable_projects.named(project_ids.values.flatten.uniq).to_h { [it.id, it.title] }

        ->(id, _) { project_ids.fetch(id, NONE).map { [it, names[it]] } }
      end

      def shared_ids(sums)
        sums.values.flat_map(&:keys).tally.filter_map { |id, count| id if count > 1 }.to_set
      end

      def spread(rows, tasks)
        closed = time_report_repo.closed_seconds(rows.map { it[:task_id] }.uniq)

        rows.map do |row|
          id, seconds = row.values_at(:task_id, :seconds)
          sessions = closed.fetch(id, 0)
          scaled = row[:running] || sessions.zero? ? seconds : Rational(seconds * tasks.fetch(id).last, sessions)

          [id, row[:worked_on], scaled]
        end
      end

      def sums(keys, pieces)
        pieces.each_with_object(Hash.new { |hash, key| hash[key] = Hash.new(0) }) do |(id, day, seconds), sums|
          keys.call(id, day).each { sums[it][id] += seconds }
        end
      end

      def tag_keys(ids)
        names = time_report_repo.tag_names(ids)

        ->(id, _) { names.fetch(id, NONE).map { [it, it] } }
      end

      def task_times(seconds_by_task, tasks, shared)
        found = seconds_by_task.filter_map do |id, seconds|
          next unless seconds.round.positive?

          Structs::TaskTime.new(id:, title: tasks.fetch(id).first, seconds: seconds.round, shared: shared.include?(id))
        end

        found.sort_by { [-it.seconds, it.title, it.id] }
      end

      def total(pieces) = pieces.group_by(&:first).sum { |_, found| found.sum(&:last).round }

      def worked(from, to)
        rows = time_report_repo.seconds_by_day(from, to)
        unspread = time_report_repo.totals_closed_between(from, to)
        tasks = time_report_repo.titled_tasks((rows.map { it[:task_id] } + unspread.map(&:first)).uniq)

        [tasks, spread(rows, tasks) + unspread]
      end
    end
  end
end
