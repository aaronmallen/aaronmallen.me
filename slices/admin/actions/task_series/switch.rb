# frozen_string_literal: true

module Admin
  module Actions
    module TaskSeries
      class Switch < Action
        PAUSED = "tasks_page.toasts.series_paused"
        RECURRING = Blog::Types::TaskTab["recurring"]
        RESUMED = "tasks_page.toasts.series_resumed"

        include Deps[
          pause_task_series: "tasks.operations.pause_task_series",
          resume_task_series: "tasks.operations.resume_task_series",
          task_queries: "tasks.repos.task_queries",
          task_series_queries: "tasks.repos.task_series_queries",
        ]

        def handle(request, response)
          series = task_series_queries.by_id(record_id(request))
          halt 404 unless series

          on = request.params[:on] == Blog::Constants::CHECKED
          halt 500 if switch(series.id, on).failure?

          toast(response, on ? RESUMED : PAUSED, task: title(series))
          response.redirect_to(routes.path(:admin_tasks, filter: RECURRING))
        end

        private

        def switch(id, on) = (on ? resume_task_series : pause_task_series).call(id)

        def title(series) = task_queries.by_id(series.task_id).title
      end
    end
  end
end
