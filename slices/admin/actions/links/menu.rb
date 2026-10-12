# frozen_string_literal: true

module Admin
  module Actions
    module Links
      class Menu < Action
        include Deps[short_link_queries: "shares.repos.short_link_queries"]

        def handle(request, response)
          link = short_link_queries.find(record_id(request)) || halt(404)
          return_to = auth_session(request).admin_return_path(request.params[:return_to])

          response.render(view, link:, return_to:)
        end
      end
    end
  end
end
