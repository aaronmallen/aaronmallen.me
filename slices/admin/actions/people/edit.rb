# frozen_string_literal: true

module Admin
  module Actions
    module People
      class Edit < Action
        include Deps[
          build_person_editor: "operations.build_person_editor",
          person_queries: "social.repos.person_queries",
        ]

        def handle(request, response)
          person = person_queries.by_id(record_id(request))
          not_found(response) unless person

          response.render(view, **build_person_editor.call(person:))
        end
      end
    end
  end
end
