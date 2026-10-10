# frozen_string_literal: true

module Tasks
  module Operations
    class SnoozeTasks < Blog::Operation
      include Deps[task_queries: "repos.task_queries", task_source_mutations: "repos.task_source_mutations"]

      def call(ids, ends_at)
        each_record(ids) { single(it, ends_at) }
      end

      private

      def single(id, ends_at)
        found(task_source_mutations.snooze(id, ends_at)).fmap { task_queries.by_id(id) }
      end
    end
  end
end
