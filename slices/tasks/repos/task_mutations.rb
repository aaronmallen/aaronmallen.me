# frozen_string_literal: true

module Tasks
  module Repos
    class TaskMutations < Blog::DB::Repo
      CANCELED = Blog::Types::TaskStatus["canceled"]
      DONE = Blog::Types::TaskStatus["done"]
      EXTERNAL = Blog::Types::TaskList["external"]
      NEXT = Blog::Types::TaskList["next"]

      root :tasks

      include Deps[order_positions: "operations.order_task_positions"]

      stamped_commands :create, :update
      commands delete: :by_pk

      def add_tags(id, names) = task_tags.add(id, tags.in_scope(task_tags.tag_scope).by_names(names).pluck(:id))

      def append(**fields)
        transaction do
          tasks.lock_until_commit
          create(**fields, position: tasks.last_position + 1)
        end
      end

      def cancel(id, at: Time.now) = update(id, status: CANCELED, completed_at: at)

      def complete(id, at: Time.now) = update(id, status: DONE, completed_at: at)

      def join_sprint(id, sprint_id) = update(id, list: nil, sprint_id:)

      def link(from_task_id, to_task_id, type) = task_links.command(:create).call(from_task_id:, to_task_id:, type:)

      def move_to_list(id, list, at: Time.now)
        transaction do
          tasks.by_pk(id).pause(at)
          update(id, list:, sprint_id: nil, carried_count: 0)
        end
      end

      def place(task, after_id)
        transaction do
          tasks.lock_until_commit
          moves = order_positions.call(tasks.beside(task).in_order.to_a, task.id, after_id)
          moves&.each { |id, position| update(id, position:) }
        end
      end

      def replace_tags(id, names) = task_tags.retag(id, names, tags)

      def return_to_list(id, at: Time.now) = move_to_list(id, tasks.sourced.by_pk(id).exist? ? EXTERNAL : NEXT, at:)

      def unlink(id, other_id) = task_links.between(id, other_id).delete
    end
  end
end
