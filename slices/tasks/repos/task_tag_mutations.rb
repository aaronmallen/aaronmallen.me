# frozen_string_literal: true

module Tasks
  module Repos
    class TaskTagMutations < Blog::DB::Repo
      root :task_tags

      def add(task_id, name) = task_tags.tag(task_id, [name], tags)

      def remove(task_id, name) = task_tags.untag(task_id, [name], tags)
    end
  end
end
