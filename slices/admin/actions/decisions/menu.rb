# frozen_string_literal: true

module Admin
  module Actions
    module Decisions
      class Menu < Action
        PRIVATE = Blog::Types::TagScope["private"]

        include Deps[decision_queries: "decisions.repos.decision_queries", tag_queries: "tags.repos.tag_queries"]

        def handle(request, response)
          decision = decision_queries.by_id(record_id(request)) || halt(404)
          return_to = auth_session(request).admin_return_path(request.params[:return_to])

          response.render(view, decision:, tags: tag_queries.all_in(PRIVATE), return_to:)
        end
      end
    end
  end
end
