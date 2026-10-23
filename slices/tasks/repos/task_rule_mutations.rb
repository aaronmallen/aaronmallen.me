# frozen_string_literal: true

module Tasks
  module Repos
    class TaskRuleMutations < Blog::DB::Repo
      root :task_rules

      stamped_commands :create, :update
      commands delete: :by_pk

      def fill_project(task_ids, project_id)
        return if project_id.nil? || task_ids.empty?

        filled = tasks.where(id: task_ids, project_id: nil).stamped(:update, result: :many).call(project_id:)
        task_tags.carry(filled.map { it[:id] }, tags, project_id:)
      end

      def replace_projects(id, project_ids)
        task_rule_projects.replace(id, project_ids)
        task_rule_tags.carry([id], tags, project_id: project_ids.first)
      end

      def replace_tags(id, names, project_id) = task_rule_tags.retag(id, names, tags, project_id:)

      def tag_tasks(task_ids, names) = task_tags.tag_in_projects(task_ids, names, tags)
    end
  end
end
