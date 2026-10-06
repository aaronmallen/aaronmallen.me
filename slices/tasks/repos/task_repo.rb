# frozen_string_literal: true

module Tasks
  module Repos
    class TaskRepo < Blog::DB::Repo
      CANCELED = Blog::Types::TaskStatus["canceled"]
      DONE = Blog::Types::TaskStatus["done"]
      EXTERNAL = Blog::Types::TaskList["external"]
      KEY = /\A#?(\d{1,9})\z/
      NEXT = Blog::Types::TaskList["next"]
      TAG_SCOPE = Blog::Types::TagScope["private"]

      stamped_commands :create, :update
      commands delete: :by_pk

      def add_tags(id, names) = task_tags.add(id, tags.in_scope(TAG_SCOPE).by_names(names).pluck(:id))

      def all_open = tasks.open.in_order.to_a

      def append(**fields)
        transaction do
          tasks.lock_until_commit
          create(**fields, position: next_position)
        end
      end

      def by_id(id) = with_details.by_pk(id).one

      def by_tag(tag) = with_details.combine(:sprint).tagged([tag]).open_first.to_a

      def cancel(id, at: Time.now) = update(id, status: CANCELED, completed_at: at)

      def complete(id, at: Time.now) = update(id, status: DONE, completed_at: at)

      def detailed(id) = with_details.combine(:sprint).by_pk(id).one

      def exist?(id) = tasks.by_pk(id).exist?

      def filtered(page:, **filters)
        found = tasks.narrowed(**filters)
        rows = found.detailed.combine(:sprint).newest_first.paged(page).to_a

        Structs::FoundTasks.new(paged: page.fill(rows), total: found.count)
      end

      def finished(page, **search)
        page.fill(with_details.combine(:sprint).closed.searched(**search).newest_first.paged(page).to_a)
      end

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

      def move_to_list(id, list, at: Time.now)
        transaction do
          tasks.by_pk(id).pause(at)
          update(id, list:, sprint_id: nil, carried_count: 0)
        end
      end

      def open_after(task) = beside(task).following(task).limit(1).one

      def open_before(task) = beside(task).preceding(task).limit(1).one

      def open_counts(sprint_id, planned_ids)
        tasks.open_counts(sprint_id, planned_ids).one.to_h.transform_keys(&:to_s)
      end

      def open_in_list(list) = with_details.in_list(list).open.in_order.to_a

      def open_in_list_page(list, page, **search)
        page.fill(with_details.in_list(list).open.searched(**search).in_order.paged(page).to_a)
      end

      def open_in_sprint(sprint_id, **search) = with_details.for_sprint(sprint_id).open.searched(**search).in_order.to_a

      def open_in_sprint_page(sprint_id, page, **search)
        page.fill(with_details.for_sprint(sprint_id).open.searched(**search).in_order.paged(page).to_a)
      end

      def place(task, after_id)
        transaction do
          tasks.lock_until_commit
          moves = Placement.moves(beside(task).in_order.to_a, task.id, after_id)
          moves&.each { |id, position| update(id, position:) }
        end
      end

      def replace_tags(id, names) = task_tags.replace(id, tags.claim(names, scope: TAG_SCOPE).values_at(*names))

      def return_to_list(id, at: Time.now) = move_to_list(id, tasks.sourced.by_pk(id).exist? ? EXTERNAL : NEXT, at:)

      def unlink(id, other_id) = task_links.between(id, other_id).delete

      private

      def beside(task) = (task.listed? ? tasks.in_list(task.list) : tasks.for_sprint(task.sprint_id)).open

      def next_position = tasks.last_position + 1

      def with_details = tasks.detailed
    end
  end
end
