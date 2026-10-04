# frozen_string_literal: true

module API
  module Actions
    module Decisions
      class Index < Action
        include Deps[endpoint: "endpoints.list_decisions"]

        def handle(request, response) = answer(response, endpoint.call(paged_query(request, :status, :tag)))
      end
    end
  end
end
