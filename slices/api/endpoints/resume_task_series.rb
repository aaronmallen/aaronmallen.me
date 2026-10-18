# frozen_string_literal: true

module API
  module Endpoints
    class ResumeTaskSeries < TaskSeriesEndpoint
      SCHEMA = Helpers::Schema.by_id
      REPLY = ROW

      include Deps[resume_task_series: "tasks.operations.resume_task_series"]

      def handle(id:) = shown(resume_task_series.call(id), id)

      private

      def going_public(fields)
        PUBLIC_TASK if task_queries.public_board_slugs([task_series_queries.by_id(fields[:id])&.task_id]).any?
      end
    end
  end
end
