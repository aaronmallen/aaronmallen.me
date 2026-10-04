# frozen_string_literal: true

module API
  module Endpoints
    class MarkMessagesRead < BulkMessageEndpoint
      ACT = Blog::Types::MessageBulkAction["read"]
    end
  end
end
