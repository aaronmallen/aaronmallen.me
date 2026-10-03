# frozen_string_literal: true

module Tasks
  module Repos
    class TaskRepo < Blog::DB::Repo
      CANCELED = Blog::Types::TaskStatus["canceled"]
      DONE = Blog::Types::TaskStatus["done"]
      EXTERNAL = Blog::Types::TaskList["external"]
      KEY = /\A#?(\d{1,9})\z/
      NEXT = Blog::Types::TaskList["next"]
      OPEN = Blog::Types::TaskStatus["open"]
      TAG_SCOPE = Blog::Types::TagScope["private"]

      commands :create, use: :timestamps, plugins_options: { timestamps: { timestamps: %i[created_at updated_at] } }
      commands update: :by_pk, use: :timestamps, plugins_options: { timestamps: { timestamps: %i[updated_at] } }
      commands delete: :by_pk

      def add_tags(id, names) = task_tags.add(id, tags.in_scope(TAG_SCOPE).by_names(names).pluck(:id))

      def all_open = tasks.open.in_order.to_a

      def append(**fields)
        transaction do
          tasks.lock_positions_until_commit
          create(**fields, position: next_position)
        end
      end

      def by_id(id) = with_details.by_pk(id).one

      def by_source(provider, remote_id) = with_details.where(id: task_sources.at(provider, remote_id).task_ids).one

      def cancel(id, at: Time.now) = update(id, status: CANCELED, completed_at: at)

      def carry_forward(sprint_id, at: Time.now)
        carried = tasks.unfinished_in(sprints.before_sprint(sprint_id).ids)

        task_events.track(carried.pluck(:id), at) do
          work_sessions.split(carried.in_progress.pluck(:id), at)
          carried.carry_into(sprint_id)
        end
      end

      def complete(id, at: Time.now) = update(id, status: DONE, completed_at: at)

      def detailed(id) = with_details.combine(:sprint).by_pk(id).one

      def exist?(id) = tasks.by_pk(id).exist?

      def filtered(statuses:, from:, to:, page:)
        found = with_details.combine(:sprint)
        found = found.where(status: statuses) unless statuses.empty?
        found = found.touched_between(from, to) if from || to

        page.fill(found.newest_first.paged(page).to_a)
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
          pause(tasks.by_pk(id), at)
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
          tasks.lock_positions_until_commit
          moves = Placement.moves(beside(task).in_order.to_a, task.id, after_id)
          moves&.each { |id, position| update(id, position:) }
        end
      end

      def release_sprint(sprint_id, at: Time.now)
        held = tasks.for_sprint(sprint_id)

        task_events.track(held.pluck(:id), at) do
          release(held.sourced, EXTERNAL, at)
          release(held.unsourced, NEXT, at)
        end
      end

      def replace_tags(id, names) = task_tags.replace(id, tags.claim(names, scope: TAG_SCOPE).values_at(*names))

      def return_to_list(id, at: Time.now) = move_to_list(id, tasks.sourced.by_pk(id).exist? ? EXTERNAL : NEXT, at:)

      def unlink(id, other_id) = task_links.between(id, other_id).delete

      private

      def beside(task) = (task.listed? ? tasks.in_list(task.list) : tasks.for_sprint(task.sprint_id)).open

      def next_position = tasks.last_position + 1

      def pause(held, at)
        running = held.in_progress
        work_sessions.close(running.dataset.select(:id), at)
        running.stamped(:update, result: :many).call(status: OPEN)
      end

      def release(held, list, at)
        pause(held, at)
        held.stamped(:update, result: :many).call(list:, sprint_id: nil)
      end

      def with_details = tasks.combine(:source, :tags, incoming_links: :from_task, outgoing_links: :to_task)
    end
  end
end
