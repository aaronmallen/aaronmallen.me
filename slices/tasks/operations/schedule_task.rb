# frozen_string_literal: true

module Tasks
  module Operations
    class ScheduleTask < Blog::Operation
      OPEN = Blog::Types::TaskStatus["open"]

      include Deps[
        current_sprint: "operations.current_sprint",
        sprint_repo: "repos.sprint_repo",
        task_repo: "repos.task_repo",
        work_session_repo: "repos.work_session_repo",
      ]

      def call(id, date, now: Time.now)
        task = step find(id)
        asked = Blog::Types::TrimmedText[date]
        return [:unscheduled, unschedule(task, now)] if asked.empty?

        day = step parse(asked)
        placed = asked == held(task) ? task : place(task, day, now)

        [day == Blog::TimeZone.today(now) ? :pulled_in : :scheduled, placed, day]
      end

      private

      def ahead(day, now) = day >= Blog::TimeZone.today(now) ? Success(day) : Failure(:past)

      def find(id)
        task = task_repo.by_id(id)

        task ? Success(task) : Failure(:not_found)
      end

      def held(task)
        return Blog::Constants::EMPTY_STRING unless task.in_sprint?

        sprint_repo.by_id(task.sprint_id).sprint_date.iso8601
      end

      def join(task, day, now)
        transaction do
          next task_repo.join_sprint(task.id, step(current_sprint.call(now:)).id) if day == Blog::TimeZone.today(now)

          wait(task, day, now)
        end
      end

      def parse(date)
        day = Blog::TimeZone.parse_day(date)

        day ? Success(day) : Failure(:invalid)
      end

      def place(task, day, now)
        step ahead(day, now)

        join(task, day, now)
      end

      def unschedule(task, now) = task.in_sprint? ? task_repo.return_to_list(task.id, at: now) : task

      def wait(task, day, now)
        work_session_repo.close(task.id, now)
        task_repo.update(task.id, list: nil, sprint_id: sprint_repo.claim(day).id, **waiting(task))
      end

      def waiting(task) = task.in_progress? ? { status: OPEN } : Blog::Constants::EMPTY_HASH
    end
  end
end
