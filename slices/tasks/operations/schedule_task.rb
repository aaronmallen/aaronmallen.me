# frozen_string_literal: true

module Tasks
  module Operations
    class ScheduleTask < Blog::Operation
      OPEN = Blog::Types::TaskStatus["open"]

      include Deps[
        current_sprint: "operations.current_sprint",
        sprint_mutations: "repos.sprint_mutations",
        sprint_queries: "repos.sprint_queries",
        task_event_mutations: "repos.task_event_mutations",
        task_mutations: "repos.task_mutations",
        task_queries: "repos.task_queries",
        work_session_mutations: "repos.work_session_mutations",
      ]

      def call(id, date, now: Time.now)
        task = step find(id)
        asked = Blog::Types::TrimmedText[date]
        step movable(task, asked)
        return [:unscheduled, unschedule(task, now)] if asked.empty?

        day = step parse(asked)
        placed = asked == held(task) ? task : place(task, day, now)

        [day == Blog::TimeZone.today(now) ? :pulled_in : :scheduled, placed, day]
      end

      private

      def ahead(day, now) = day >= Blog::TimeZone.today(now) ? Success(day) : Failure(:past)

      def find(id)
        found(task_queries.by_id(id))
      end

      def held(task)
        return Blog::Constants::EMPTY_STRING unless task.in_sprint?

        sprint_queries.by_id(task.sprint_id).sprint_date.iso8601
      end

      def join(task, day, now)
        transaction do
          sprint = step current_sprint.call(now:) if day == Blog::TimeZone.today(now)

          task_event_mutations.track(task.id, now) do
            sprint ? task_mutations.join_sprint(task.id, sprint.id) : wait(task, day, now)
          end
        end
      end

      def movable(task, asked) = task.closed? && asked != held(task) ? Failure(:closed) : Success(task)

      def parse(date)
        day = Blog::TimeZone.parse_day(date)

        day ? Success(day) : Failure(:invalid)
      end

      def place(task, day, now)
        step ahead(day, now)

        join(task, day, now)
      end

      def unschedule(task, now)
        return task unless task.in_sprint?

        task_event_mutations.track(task.id, now) { task_mutations.return_to_list(task.id, at: now) }
      end

      def wait(task, day, now)
        work_session_mutations.close(task.id, now)
        task_mutations.update(task.id, list: nil, sprint_id: sprint_mutations.claim(day).id, **waiting(task))
      end

      def waiting(task) = task.in_progress? ? { status: OPEN } : Blog::Constants::EMPTY_HASH
    end
  end
end
