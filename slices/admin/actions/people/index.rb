# frozen_string_literal: true

module Admin
  module Actions
    module People
      class Index < Action
        include Deps[
          build_person_editor: "operations.build_person_editor",
          networks: "social.networks.all",
          person_queries: "social.repos.person_queries",
        ]

        def handle(_request, response)
          people = person_queries.all
          editors = [nil, *people].map { build_person_editor.call(person: it) }

          response.render(view, people:, editors:, searchable:)
        end

        private

        def searchable = Blog::Types::NetworkName.values.select { networks.fetch(it).configured? }
      end
    end
  end
end
