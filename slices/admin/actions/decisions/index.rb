# frozen_string_literal: true

module Admin
  module Actions
    module Decisions
      class Index < Action
        include Deps[
          "settings",
          count_by_status: "decisions.queries.count_by_status",
          decisions_by_status: "decisions.queries.by_status",
        ]

        def handle(request, response)
          filter = Blog::Types::DecisionStatusParam[request.params[:status]]
          decisions = decisions_by_status.call(filter, requested_page(request, response, settings.page_size[:admin]))
          not_found(response) if decisions.past_end?

          response[:counts] = count_by_status.call
          response[:decisions] = decisions
          response[:filter] = filter
        end
      end
    end
  end
end
