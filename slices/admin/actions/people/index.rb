# frozen_string_literal: true

module Admin
  module Actions
    module People
      class Index < Action
        include Deps[people: "social.queries.people"]

        def handle(_request, response)
          response.render(view, people: people.call)
        end
      end
    end
  end
end
