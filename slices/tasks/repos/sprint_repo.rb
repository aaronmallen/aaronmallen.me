# frozen_string_literal: true

module Tasks
  module Repos
    class SprintRepo < Blog::DB::Repo
      EXTERNAL = Blog::Types::TaskList["external"]
      NEXT = Blog::Types::TaskList["next"]

      commands delete: :by_pk

      def after(date) = sprints.dated_after(date).in_date_order.to_a

      def between(first, last, page) = page.fill(sprints.dated_between(first, last).in_date_order.paged(page).to_a)

      def by_id(id) = sprints.by_pk(id).one

      def carry_forward(sprint_id, at: Time.now)
        carried = tasks.unfinished_in(sprints.before_sprint(sprint_id).ids)

        task_events.track(carried.pluck(:id), at) do
          work_sessions.split(carried.in_progress.pluck(:id), at)
          carried.carry_into(sprint_id)
        end
      end

      def claim(date) = on(date) || start(date)

      def count_arrivals(id, arrived) = sprints.count_arrivals(id, arrived)

      def counted_between(first, last) = sprints.dated_between(first, last).with_task_counts.in_date_order.to_a

      def lock_roll_over = sprints.lock_roll_over_until_commit

      def on(date) = sprints.on(date).one

      def release(sprint_id, at: Time.now)
        held = tasks.for_sprint(sprint_id)

        task_events.track(held.pluck(:id), at) do
          return_to(held.sourced, EXTERNAL, at)
          return_to(held.unsourced, NEXT, at)
        end
      end

      private

      def return_to(held, list, at)
        held.pause(at)
        held.stamped(:update, result: :many).call(list:, sprint_id: nil)
      end

      def start(date)
        sprints.insert_missing(date)
        on(date)
      end
    end
  end
end
