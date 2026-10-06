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

      def see(task_ids, at) = where(task_id: task_ids).unseen.stamped(:update, result: :many).call(seen_at: at)

      def task_ids = unordered.dataset.select(:task_id)

      def unseen = where(seen_at: nil)
    end
  end
end
