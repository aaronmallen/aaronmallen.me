# frozen_string_literal: true

module Tasks
  module Repos
    class TimeReportRepo < DB::Repo
      def closed_seconds(task_ids) = work_sessions.closed_seconds_by_task(task_ids)

      def project_ids(task_ids) = record_links.project_ids_by_task(task_ids)

      def seconds_by_day(from, to) = work_sessions.seconds_by_day(from, to)

      def tag_names(task_ids) = task_tags.names_by_task(task_ids)

      def titled_tasks(ids) = tasks.titles_and_totals(ids)

      def totals_closed_between(from, to) = tasks.totals_closed_between(from, to)
    end
  end
end
