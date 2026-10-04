# frozen_string_literal: true

module API
  module Endpoints
    class MarkWebmentionsSpam < BulkWebmentionEndpoint
      ACT = Blog::Types::WebmentionVerdict["spam"]
    end
  end
end
