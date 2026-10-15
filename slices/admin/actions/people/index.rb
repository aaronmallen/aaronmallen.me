# frozen_string_literal: true

module Admin
  module Actions
    module People
      class Index < Action
        include Deps[
          build_person_editor: "operations.build_person_editor",
          networks: "networks.all",
          person_queries: "social.repos.person_queries",
        ]

        def handle(_request, response)
          response.render(view, people: person_queries.all, editor: build_person_editor.call, searchable:)
        end

        private

        def searchable
          Blog::Types::NetworkName.values.select { networks.fetch(it).then { it.respond_to?(:search) && it.configured? } }
        end
      end
    end
  end
end
