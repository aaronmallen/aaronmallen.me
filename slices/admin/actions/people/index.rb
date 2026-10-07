# frozen_string_literal: true

module Admin
  module Actions
    module People
      class Index < Action
        include Deps[person_queries: "social.repos.person_queries"]

        def handle(_request, response)
          response.render(view, people: person_queries.all)
        end
      end
    end
  end
end
