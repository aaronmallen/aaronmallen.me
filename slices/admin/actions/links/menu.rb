# frozen_string_literal: true

module Admin
  module Actions
    module Links
      class Menu < Action
        include Deps[short_link_queries: "shares.repos.short_link_queries"]

        def handle(request, response)
          link = short_link_queries.find(record_id(request)) || halt(404)

          response.render(view, link:, return_to: back_here(request))
        end
      end
    end
  end
end
