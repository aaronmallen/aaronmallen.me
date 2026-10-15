# frozen_string_literal: true

module API
  module Endpoints
    class CancelTasks < BulkTaskEndpoint
      ACT = Blog::Types::TaskBulkAction["cancel"]
    end
  end
end
