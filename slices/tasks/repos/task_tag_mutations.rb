# frozen_string_literal: true

module Tasks
  module Repos
    class TaskTagMutations < Blog::DB::Repo
      root :task_tags

      def add(task_ids, name) = task_tags.tag(task_ids, [name], tags)

      def remove(task_ids, name) = task_tags.untag(task_ids, [name], tags)
    end
  end
end
