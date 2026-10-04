# frozen_string_literal: true

module API
  module Actions
    module Attention
      class Index < Action
        include Deps[endpoint: "endpoints.list_attention"]

        def handle(_request, response) = answer(response, endpoint.call)
      end
    end
  end
end
