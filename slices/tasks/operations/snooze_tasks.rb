# frozen_string_literal: true

module Tasks
  module Operations
    class SnoozeTasks < Operation
      include Deps[task_repo: "repos.task_repo", task_source_repo: "repos.task_source_repo"]

      def call(ids, ends_at)
        each_record(ids) { single(it, ends_at) }
      end

      private

      def single(id, ends_at)
        found(task_source_repo.snooze(id, ends_at)).fmap { task_repo.by_id(id) }
      end
    end
  end
end
