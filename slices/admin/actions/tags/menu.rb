# frozen_string_literal: true

module Admin
  module Actions
    module Tags
      class Menu < Action
        include Deps[tag_queries: "tags.repos.tag_queries"]

        def handle(request, response)
          scope = Blog::Types::TagScopeParam[request.params[:scope]]
          tag = tag_queries.find_in(scope, record_id(request)) || halt(:not_found)

          response.render(view, tag:, return_to: back_here(request))
        end
      end
    end
  end
end
