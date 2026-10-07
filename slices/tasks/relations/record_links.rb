# frozen_string_literal: true

module Tasks
  module Relations
    class RecordLinks < Blog::DB::Relation
      PROJECT = Blog::Types::RecordKind["project"]
      TASK = Blog::Types::RecordKind["task"]

      schema :record_links, infer: true

      def link_projects(task_ids, project_ids)
        rows = task_ids.product(project_ids).map do |task_id, project_id|
          { left_kind: TASK, left_id: task_id, right_kind: PROJECT, right_id: project_id }
        end

        dataset.insert_conflict.multi_insert(rows) unless rows.empty?
      end

      def project_ids_by_task(task_ids)
        linked = where(left_kind: TASK, left_id: task_ids, right_kind: PROJECT)

        linked.dataset.unordered.to_hash_groups(:left_id, :right_id)
      end
    end
  end
end
