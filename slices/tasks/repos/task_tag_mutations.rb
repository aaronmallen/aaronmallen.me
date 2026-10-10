# frozen_string_literal: true

module Tasks
  module Repos
    class TaskTagMutations < Blog::DB::Repo
      TAG_SCOPE = Blog::Types::TagScope["private"]

      root :task_tags

      def add(task_id, name) = task_tags.add_missing([task_id], tags.claim([name], scope: TAG_SCOPE).values)

      def remove(task_id, name) = task_tags.for_owner(task_id).where(tag_id: tag_ids(name)).delete

      private

      def tag_ids(name) = tags.in_scope(TAG_SCOPE).by_names([name]).pluck(:id)
    end
  end
end
