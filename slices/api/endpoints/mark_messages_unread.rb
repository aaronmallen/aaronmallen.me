# frozen_string_literal: true

module API
  module Endpoints
    class MarkMessagesUnread < BulkMessageEndpoint
      ACT = Blog::Types::MessageBulkAction["unread"]
    end
  end
end
