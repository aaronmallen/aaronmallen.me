# frozen_string_literal: true

module API
  module Endpoints
    class ListTaskSeries < TaskSeriesEndpoint
      SCHEMA = { additionalProperties: false }.freeze
      REPLY = Helpers::Schema.object({ task_series: Helpers::Schema.list(ROW) }).freeze

      def handle = Success(task_series: task_series_queries.listed.map { row(it) })
    end
  end
end
