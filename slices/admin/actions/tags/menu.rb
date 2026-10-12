# frozen_string_literal: true

module Admin
  module Actions
    module Tags
      class Menu < Action
        include Deps[tag_queries: "tags.repos.tag_queries"]

        def handle(request, response)
          scope = Blog::Types::TagScopeParam[request.params[:scope]]
          tag = tag_queries.find_in(scope, record_id(request)) || halt(404)
          return_to = auth_session(request).admin_return_path(request.params[:return_to])

          response.render(view, tag:, return_to:)
        end
      end
    end
  end
end
