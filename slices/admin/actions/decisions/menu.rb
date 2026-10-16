# frozen_string_literal: true

module Admin
  module Actions
    module Decisions
      class Menu < Action
        PRIVATE = Blog::Types::TagScope["private"]

        include Deps[decision_queries: "decisions.repos.decision_queries", tag_queries: "tags.repos.tag_queries"]

        def handle(request, response)
          decision = decision_queries.by_id(record_id(request)) || halt(404)

          response.render(view, decision:, tags: tag_queries.all_in(PRIVATE, mail: false),
                                return_to: back_here(request))
        end
      end
    end
  end
end
