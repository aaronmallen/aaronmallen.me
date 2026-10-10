# frozen_string_literal: true

module Admin
  module Actions
    module Decisions
      class Index < Action
        include Deps[decision_queries: "decisions.repos.decision_queries"]

        def handle(request, response)
          filter = Blog::Types::DecisionStatusParam[request.params[:status]]
          decisions = decision_queries.page_by_status(filter, page(request, response))
          not_found(response) if decisions.past_end?

          response[:counts] = decision_queries.count_by_status
          response[:decisions] = decisions
          response[:filter] = filter
        end

        private

        def page(request, response) = requested_page(request, response)
      end
    end
  end
end
