# auto_register: false
# frozen_string_literal: true

module API
  module Endpoints
    class TaskSeriesEndpoint < Endpoint
      TASK = Helpers::Schema.object(
        {
          id: Helpers::Schema::INTEGER,
          title: Helpers::Schema::STRING,
          status: { type: "string", enum: Blog::Types::TaskStatus.values },
          sprint_on: Helpers::Schema.nullable(Helpers::Schema::DAY),
        },
      ).freeze

      ROW = Helpers::Schema.widen(
        Serializers::TaskSeries::SCHEMA,
        task: TASK.merge(description: "the series' current copy; the next copy follows when it closes"),
      ).freeze

      include Deps[task_series_queries: "tasks.repos.task_series_queries"]

      private

      def day(date) = date&.iso8601

      def row(series)
        task = series.task

        serialized(Serializers::TaskSeries, series).merge(
          task: { id: task.id, title: task.title, status: task.status, sprint_on: day(task.sprint&.sprint_date) },
        )
      end

      def shown(result, id)
        case result
          in Success(*) then Success(row(task_series_queries.shown(id)))
          in Failure(:not_found) then missing(Tasks::SERIES, id)
          else failed(Helpers::Wording::UNSAVED)
        end
      end
    end
  end
end
