# frozen_string_literal: true

module Tasks
  module Relations
    class TaskSources < Blog::DB::Relation
      schema :task_sources, infer: true do
        associations do
          belongs_to :task
        end
      end

      def at(provider, remote_id) = where(provider:, remote_id:)

      def task_ids = unordered.dataset.select(:task_id)
    end
  end
end
