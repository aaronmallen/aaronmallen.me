# frozen_string_literal: true

module Tasks
  module Repos
    class SprintMutations < Blog::DB::Repo
      EXTERNAL = Blog::Types::TaskList["external"]
      NEXT = Blog::Types::TaskList["next"]

      root :sprints

      include Deps[diff: "operations.diff_task_history"]

      commands delete: :by_pk

      def carry_forward(sprint_id, at: Time.now)
        carried = tasks.unfinished_in(sprints.before_sprint(sprint_id).ids)

        task_events.track(carried.pluck(:id), at, diff:) do
          work_sessions.split(carried.in_progress.pluck(:id), at)
          carried.carry_into(sprint_id)
        end
      end

      def claim(date) = on(date) || start(date)

      def count_arrivals(id, arrived) = sprints.count_arrivals(id, arrived)

      def lock_roll_over = sprints.lock_until_commit

      def release(sprint_id, at: Time.now)
        held = tasks.for_sprint(sprint_id)

        task_events.track(held.pluck(:id), at, diff:) do
          return_to(held.sourced, EXTERNAL, at)
          return_to(held.unsourced, NEXT, at)
        end
      end

      private

      def on(date) = sprints.on(date).one

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
