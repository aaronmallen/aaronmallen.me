# frozen_string_literal: true

module Tasks
  module Operations
    class ReachIssues
      EMPTY_ARRAY = Blog::Constants::EMPTY_ARRAY
      REACHABLE = %w[open started unassigned].map { Blog::Types::TaskSourceState[it] }.freeze

      include Deps[task_link_queries: "repos.task_link_queries"]

      def call(client, assigned, known)
        ids = ends(assigned, known)
        return EMPTY_ARRAY if ids.empty?

        client.issues(ids.to_h { [it, nil] }).select { reachable?(it) }
      end

      private

      def ends(assigned, known)
        by_task = assigned.to_h { [known.fetch(it[:id]).task_id, it] }
        open_ids = task_link_queries.open_ids(by_task.keys)
        named = by_task.values_at(*open_ids).flat_map { it.fetch(:relations, EMPTY_ARRAY) }

        named.map { it[:remote_id] }.uniq - known.keys
      end

      def reachable?(issue) = REACHABLE.include?(issue[:remote_state]) && issue.key?(:title)
    end
  end
end
