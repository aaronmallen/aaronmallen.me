# frozen_string_literal: true

module Tasks
  module Operations
    class MarkTasksSeen < Blog::Operation
      include Deps[
        task_queries: "repos.task_queries",
        task_source_mutations: "repos.task_source_mutations",
        task_source_queries: "repos.task_source_queries",
      ]

      def call(ids, at: Time.now)
        return ids if ids.empty?

        step synced(ids)
        task_source_mutations.see(ids, at)
        ids
      end

      private

      def synced(ids)
        missing = ids - task_source_queries.synced_task_ids(ids)
        return Success(ids) if missing.empty?

        Failure[:record, missing.first, task_queries.exist?(missing.first) ? :unsourced : :not_found]
      end
    end
  end
end
