# frozen_string_literal: true

module Tasks
  module Relations
    class TaskComments < Blog::DB::Relation
      schema :task_comments, infer: true do
        associations do
          belongs_to :task
        end
      end

      def for_task(task_id) = where(task_id:)

      def local = where(remote_id: nil)

      def oldest_first = order(self[:created_at].asc, self[:id].asc)
    end
  end
end
