# frozen_string_literal: true

module Admin
  module Actions
    module People
      class Update < Action
        SAVED = "people_page.toasts.saved"

        include Deps[
          build_person_editor: "operations.build_person_editor",
          edit_view: "ui.views.people.edit",
          person_queries: "social.repos.person_queries",
          save_person: "social.operations.save_person",
        ]

        def handle(request, response)
          id = record_id(request)
          params = Blog::Types::Fields[request.params[:person]]

          result = save_person.call(params, id:)

          case result
            in Failure[:invalid, errors] then invalid(response, person_queries.by_id(id), params, errors)
            else settle(response, result, SAVED, routes.path(:admin_people))
          end
        end

        private

        def invalid(response, person, params, errors)
          halt 404 unless person

          response.status = 422
          response.render(edit_view, **build_person_editor.call(person:, params:, errors:))
        end
      end
    end
  end
end
