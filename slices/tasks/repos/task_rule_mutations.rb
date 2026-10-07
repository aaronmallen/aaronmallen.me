# frozen_string_literal: true

module Tasks
  module Repos
    class TaskRuleMutations < DB::Repo
      TAG_SCOPE = Blog::Types::TagScope["private"]

      root :task_rules

      stamped_commands :create, :update
      commands delete: :by_pk

      def link_projects(task_ids, project_ids) = record_links.link_projects(task_ids, project_ids)

      def replace_projects(id, project_ids) = task_rule_projects.replace(id, project_ids)

      def replace_tags(id, names)
        tag_ids = tags.claim(names, scope: TAG_SCOPE).values_at(*names)
        task_rule_tags.replace(id, tag_ids)
        tag_ids
      end

      def tag_tasks(task_ids, tag_ids) = task_tags.add_missing(task_ids, tag_ids)
    end
  end
end
