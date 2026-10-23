# frozen_string_literal: true

module Admin
  module Actions
    module Decisions
      class Menu < Action
        RECORD = Blog::Types::RecordKind["decision"]

        include Deps[decision_queries: "decisions.repos.decision_queries", tag_queries: "tags.repos.tag_queries"]

        def handle(request, response)
          decision = decision_queries.by_id(record_id(request)) || halt(:not_found)

          response.render(view, decision:, tags: tag_queries.choices_for(RECORD, decision.id),
                                return_to: back_here(request))
        end
      end
    end
  end
end
