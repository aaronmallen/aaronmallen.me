# frozen_string_literal: true

module API
  module Endpoints
    class CompleteTasks < BulkTaskEndpoint
      ACT = Blog::Types::TaskBulkAction["complete"]
    end
  end
end
