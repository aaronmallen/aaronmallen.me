# frozen_string_literal: true

module API
  module Endpoints
    class PauseTaskSeries < TaskSeriesEndpoint
      SCHEMA = Helpers::Schema.by_id
      REPLY = ROW

      include Deps[pause_task_series: "tasks.operations.pause_task_series"]

      def handle(id:) = shown(pause_task_series.call(id), id)
    end
  end
end
