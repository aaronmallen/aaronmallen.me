# frozen_string_literal: true

module Tasks
  module Repos
    class TaskRepo < Blog::DB::Repo
      DONE = Blog::Types::TaskStatus["done"]
      KEY = /\A#?(\d{1,9})\z/

      commands :create, use: :timestamps, plugins_options: { timestamps: { timestamps: %i[created_at updated_at] } }
      commands update: :by_pk, use: :timestamps, plugins_options: { timestamps: { timestamps: %i[updated_at] } }
      commands delete: :by_pk

      def all_open = tasks.open.in_order.to_a

      def by_id(id) = with_details.by_pk(id).one

      def carry_forward(sprint_id)
        tasks.unfinished_in(sprints.before_sprint(sprint_id).ids).carry_into(sprint_id)
      end

      def complete(id, at: Time.now) = update(id, status: DONE, completed_at: at)

      def detailed(id) = with_details.combine(:sprint).by_pk(id).one

      def filtered(statuses:, from:, to:)
        found = with_details.combine(:sprint)
        found = found.where(status: statuses) unless statuses.empty?
        found = found.touched_between(from, to) if from || to

        found.newest_first.to_a
      end

      def finished = with_details.combine(:sprint).done.newest_finished.to_a

      def finished_counts(day) = tasks.finished_counts(day).one.to_h

      def in_list(list) = with_details.in_list(list).in_order.to_a

      def in_sprint(sprint_id) = with_details.for_sprint(sprint_id).in_order.to_a

      def join_sprint(id, sprint_id) = update(id, list: nil, sprint_id:)

      def link(from_task_id, to_task_id, type) = task_links.command(:create).call(from_task_id:, to_task_id:, type:)

      def link_targets(id, text, limit:)
        found = tasks.linkable_from(id)
        key = text[KEY, 1]
        found = key ? found.where(id: key.to_i) : found.titled(text)

        found.open_first.limit(limit).to_a
      end

      def move_to_list(id, list) = update(id, list:, sprint_id: nil, carried_count: 0)

      def next_position = tasks.last_position + 1

      def open_in_list(list) = with_details.in_list(list).open.in_order.to_a

      def open_in_sprint(sprint_id) = with_details.for_sprint(sprint_id).open.in_order.to_a

      def release_sprint(sprint_id, list:)
        tasks.for_sprint(sprint_id).stamped(:update, result: :many).call(list:, sprint_id: nil)
      end

      def replace_tags(id, names) = task_tags.replace(id, tags.claim(names).values_at(*names))

      def search(tags:, text:, types:)
        found = with_details
        found = found.matching(text) unless text.empty?
        found = found.tagged(tags) unless tags.empty?
        found = found.of_types(named_types(types)) unless types.empty?

        found.in_order.to_a
      end

      def swap_positions(one, two)
        transaction do
          update(one.id, position: next_position)
          update(two.id, position: one.position)
          update(one.id, position: two.position)
        end
      end

      def unlink(id, other_id) = task_links.between(id, other_id).delete

      private

      def named_types(names) = names.map { task_types.named(it).ids }

      def with_details = tasks.combine(:tags, incoming_links: :from_task, outgoing_links: :to_task)
    end
  end
end
