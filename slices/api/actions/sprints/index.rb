# frozen_string_literal: true

module API
  module Actions
    module Sprints
      class Index < Action
        include Deps[endpoint: "endpoints.list_sprints"]

        def handle(request, response) = answer(response, endpoint.call(paged_query(request, :from, :to)))
      end
    end
  end
end
