# frozen_string_literal: true

module API
  module Endpoints
    class IgnoreWebmentions < BulkWebmentionEndpoint
      ACT = Blog::Types::WebmentionVerdict["ignored"]
    end
  end
end
