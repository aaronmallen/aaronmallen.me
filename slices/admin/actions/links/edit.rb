# frozen_string_literal: true

module Admin
  module Actions
    module Links
      class Edit < Action
        include Deps[short_link_queries: "shares.repos.short_link_queries"]

        def handle(request, response)
          link = short_link_queries.find(record_id(request))
          not_found(response) unless link

          response.render(view, link:, check: short_link_queries.check(link))
        end
      end
    end
  end
end
