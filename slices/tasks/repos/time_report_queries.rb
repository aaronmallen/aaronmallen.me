# frozen_string_literal: true

module Tasks
  module Repos
    class TimeReportQueries < Blog::DB::Repo
      DAY = Blog::Types::TimeGrouping["day"]
      NONE = [nil].freeze
      PROJECT = Blog::Types::TimeGrouping["project"]

      include Deps[project_queries: "projects.repos.project_queries"]

      def report(from:, to:, by:)
        grouping = Blog::Types::TimeGrouping[by]
        sessions, manual = worked(from, to)
        keys = keys_for(grouping, (sessions + manual).map(&:first).uniq)
        merged = merged(from, to, grouping, sums(keys, sessions))

        Structs::TimeReport.new(
          from:, to:, by: grouping, seconds: merged[:total] + manual.sum(&:last),
          groups: groups(grouping, sums(keys, sessions + manual), sums(keys, manual), merged),
        )
      end

      private

      def group((key, name), seconds_by_task, added, merged, tasks)
        return if tasks.empty?

        overlapped = merged < seconds_by_task.values.sum - added

        Structs::TimeGroup.new(key:, name:, seconds: merged + added, shared: tasks.any?(&:shared), overlapped:, tasks:)
      end

      def groups(grouping, sums, manual, merged)
        times = task_times_by_group(grouping, sums)

        found = sums.filter_map do |key, seconds_by_task|
          group(key, seconds_by_task, manual.fetch(key, {}).values.sum, merged[key], times[key])
        end
        found.sort_by { [it.key.nil? ? 1 : 0, it.name.to_s] }
      end

      def keys_for(grouping, ids)
        case grouping
          when DAY then ->(_, day) { [[day, day.iso8601]] }
          when PROJECT then project_keys(ids)
          else tag_keys(ids)
        end
      end

      def merged(from, to, grouping, sessions)
        keyed = grouping == DAY ? {} : sessions.transform_values(&:keys)
        found = work_sessions.merged_seconds_by_day(from, to, keyed.merge(total: sessions.values.flat_map(&:keys).uniq))
        daily = found.fetch(:total, {})

        Hash.new(0).merge(merged_groups(grouping, found, daily), total: daily.values.sum)
      end

      def merged_groups(grouping, found, daily)
        return daily.to_h { |day, seconds| [[day, day.iso8601], seconds] } if grouping == DAY

        found.transform_values { it.values.sum }
      end

      def project_keys(ids)
        project_ids = record_links.project_ids_by_task(ids)
        names = project_queries.linkable(:projects, ids: project_ids.values.flatten.uniq).to_h { [it.id, it.title] }

        ->(id, _) { project_ids.fetch(id, NONE).map { [it, names[it]] } }
      end

      def shared_ids(sums)
        sums.values.flat_map(&:keys).tally.filter_map { |id, count| id if count > 1 }.to_set
      end

      def sums(keys, pieces)
        pieces.each_with_object(Hash.new { |hash, key| hash[key] = Hash.new(0) }) do |(id, day, seconds), sums|
          keys.call(id, day).each { sums[it][id] += seconds }
        end
      end

      def tag_keys(ids)
        names = task_tags.names_by_task(ids)

        ->(id, _) { names.fetch(id, NONE).map { [it, it] } }
      end

      def task_times(seconds_by_task, titles, shared)
        found = seconds_by_task.filter_map do |id, seconds|
          next unless seconds.positive?

          Structs::TaskTime.new(id:, title: titles.fetch(id), seconds:, shared: shared.include?(id))
        end

        found.sort_by { [-it.seconds, it.title, it.id] }
      end

      def task_times_by_group(grouping, sums)
        shared = grouping == DAY ? Set.new : shared_ids(sums)
        titles = tasks.titles(sums.values.flat_map(&:keys).uniq)

        sums.transform_values { task_times(it, titles, shared) }
      end

      def worked(from, to) = [work_sessions.seconds_by_day(from, to), tasks.manual_between(from, to)]
    end
  end
end
