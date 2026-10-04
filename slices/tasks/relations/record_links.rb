# frozen_string_literal: true

module Tasks
  module Relations
    class RecordLinks < Blog::DB::Relation
      PROJECT = Blog::Types::RecordKind["project"]
      TASK = Blog::Types::RecordKind["task"]

      schema :record_links, infer: true

      def project_ids_by_task(task_ids)
        linked = where(left_kind: TASK, left_id: task_ids, right_kind: PROJECT)

        linked.dataset.unordered.to_hash_groups(:left_id, :right_id)
      end
    end
  end
end
