# frozen_string_literal: true

module Tasks
  module Relations
    class TaskRuleProjects < Blog::DB::Relation
      schema :task_rule_projects, infer: true do
        associations do
          belongs_to :task_rule
        end
      end

      def replace(id, project_ids)
        held = where(task_rule_id: id)
        held.exclude(project_id: project_ids).delete
        fresh = project_ids - held.pluck(:project_id)
        command(:create, result: :many).call(fresh.map { { task_rule_id: id, project_id: it } }) unless fresh.empty?
      end
    end
  end
end
