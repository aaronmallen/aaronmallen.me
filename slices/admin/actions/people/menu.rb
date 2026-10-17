# frozen_string_literal: true

module Admin
  module Actions
    module People
      class Menu < Action
        include Deps[person_queries: "social.repos.person_queries"]

        def handle(request, response)
          person = person_queries.by_id(record_id(request)) || halt(:not_found)

          response.render(view, person:, return_to: back_here(request))
        end
      end
    end
  end
end
