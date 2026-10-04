# frozen_string_literal: true

module API
  module Endpoints
    class ApproveWebmentions < BulkWebmentionEndpoint
      ACT = Blog::Types::WebmentionVerdict["approved"]
    end
  end
end
