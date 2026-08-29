# frozen_string_literal: true

module Tasks
  module Repos
    class TaskTypeRepo < Blog::DB::Repo
      commands :create, use: :timestamps, plugins_options: { timestamps: { timestamps: %i[created_at updated_at] } }
      commands update: :by_pk, use: :timestamps, plugins_options: { timestamps: { timestamps: %i[updated_at] } }
      commands delete: :by_pk

      def all = task_types.in_order.to_a

      def by_id(id) = task_types.by_pk(id).one

      def next_color = task_types.next_color

      def next_position = task_types.last_position + 1

      def swap_positions(one, two)
        transaction do
          update(one.id, position: next_position)
          update(two.id, position: one.position)
          update(one.id, position: two.position)
        end
      end

      def task_counts = tasks.count_by_type.to_a.to_h { [it.task_type_id, it.count] }
    end
  end
end
