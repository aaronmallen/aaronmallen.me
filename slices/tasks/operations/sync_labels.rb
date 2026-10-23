# frozen_string_literal: true

module Tasks
  module Operations
    class SyncLabels
      EMPTY_ARRAY = Blog::Constants::EMPTY_ARRAY
      LABEL_TAG = Blog::Types::Normalized::LabelTag

      include Deps[task_event_mutations: "repos.task_event_mutations", task_mutations: "repos.task_mutations"]

      def call(run, issues, tasks)
        issues.zip(tasks) { |issue, task| task&.project_id && tag(task, labels(issue), run.now) }
      end

      def import(task_id, issue, names) = task_mutations.import_tags(task_id, labels(issue), names)

      private

      def labels(issue) = issue.fetch(:labels, EMPTY_ARRAY).filter_map { LABEL_TAG.call(it) { nil } }

      def tag(task, labels, at)
        missing = labels - task.tags.filter_map { it.name if it.project_id == task.project_id }
        return if missing.empty?

        task_event_mutations.track(task.id, at, seen: false) do
          task_mutations.tag_in_project(task.id, missing, task.project_id)
        end
      end
    end
  end
end
