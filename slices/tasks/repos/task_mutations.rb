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

      def append(**fields)
        transaction do
          tasks.lock_until_commit
          create(**fields, position: tasks.last_position + 1)
        end
      end

      def cancel(id, at: Time.now) = update(id, status: CANCELED, completed_at: at)

      def carry_tags(ids, project_id) = task_tags.carry(ids, tags, project_id:)

      def complete(id, at: Time.now) = update(id, status: DONE, completed_at: at)

      def import_tags(id, labels, names)
        project_id = project_of(id)
        return tag_in_project(id, [*labels, *names], project_id) if project_id

        task_tags.add(id, tags.in_scope(task_tags.tag_scope).by_names(labels).pluck(:id))
        task_tags.tag(id, names.uniq, tags)
      end

      def join_sprint(id, sprint_id) = update(id, list: nil, sprint_id:)

      def lead(id)
        transaction do
          tasks.lock_until_commit
          update(id, position: tasks.unordered.min(:position) - 1)
        end
      end

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
          moves = order_positions.call(tasks.beside(task).in_order.select(:id, :position).to_a, task.id, after_id)
          reposition(moves) if moves&.any?
          moves
        end
      end

      def replace_tags(id, names) = task_tags.retag(id, names, tags, project_id: project_of(id))

      def return_to_list(id, at: Time.now) = move_to_list(id, tasks.sourced.by_pk(id).exist? ? EXTERNAL : NEXT, at:)

      def source_from_decision(id, decision_id) = record_links.source_from_decision(id, decision_id)

      def tag_in_project(id, names, project_id) = task_tags.tag(id, names.uniq, tags, project_id:)

      def unlink(id, other_id) = task_links.between(id, other_id).delete

      private

      def project_of(id) = tasks.by_pk(id).pluck(:project_id).first

      def reposition(moves)
        moved = Sequel.as(tasks.dataset.db.values(moves), :moves, %i[id position])
        found = tasks.dataset.unordered.from(:tasks, moved).where(Sequel[:tasks][:id] => Sequel[:moves][:id])

        found.update(position: Sequel[:moves][:position], updated_at: Time.now)
      end
    end
  end
end
