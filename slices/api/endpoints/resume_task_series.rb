# frozen_string_literal: true

module API
  module Endpoints
    class ResumeTaskSeries < TaskSeriesEndpoint
      SCHEMA = Helpers::Schema.by_id
      REPLY = ROW

      include Deps[resume_task_series: "tasks.operations.resume_task_series"]

      def handle(id:) = shown(resume_task_series.call(id), id)
    end
  end
end
