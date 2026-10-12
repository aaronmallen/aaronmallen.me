# frozen_string_literal: true

module API
  module Endpoints
    class MarkMailThreadsUnread < BulkMailThreadEndpoint
      ACT = Blog::Types::MessageBulkAction["unread"]
    end
  end
end
