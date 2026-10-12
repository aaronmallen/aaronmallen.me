# frozen_string_literal: true

module API
  module Endpoints
    class MarkMailThreadsRead < BulkMailThreadEndpoint
      ACT = Blog::Types::MessageBulkAction["read"]
    end
  end
end
