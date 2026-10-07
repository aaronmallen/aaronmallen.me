# frozen_string_literal: true

module Admin
  module Actions
    module Calendar
      class MoveTask < Action
        include Move
        include Deps[schedule_task: "tasks.operations.schedule_task", task_queries: "tasks.repos.task_queries"]

        def handle(request, response)
          task = task_queries.detailed(record_id(request))
          halt 404 unless task
          return done(request, response, :closed) if task.closed?

          schedule(request, response, task)
        end

        private

        def schedule(request, response, task)
          to = Blog::Types::TrimmedText[request.params[:to]]
          return done(request, response, :invalid) if to.empty?

          case schedule_task.call(task.id, to)
            in Success[_, _, day] then done(request, response, :moved_task, date: i18n.l(day, format: :medium))
            in Failure(:invalid | :past => refusal) then done(request, response, refusal)
            in Failure(:not_found) then halt 404
            else halt 500
          end
        end
      end
    end
  end
end
