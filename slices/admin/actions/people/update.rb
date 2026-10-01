# frozen_string_literal: true

module Admin
  module Actions
    module People
      class Update < Action
        SAVED = "people_page.toasts.saved"

        include Deps[
          build_person_editor: "operations.build_person_editor",
          edit_view: "ui.views.people.edit",
          person_by_id: "social.queries.person_by_id",
          save_person: "social.operations.save_person",
        ]

        def handle(request, response)
          id = record_id(request)
          params = Blog::Types::Fields[request.params[:person]]

          case save_person.call(params, id:)
          in Success(_) then saved(response)
          in Failure(:not_found) then halt 404
          in Failure[:invalid, errors] then invalid(response, person_by_id.call(id), params, errors)
          else halt 500
          end
        end

        private

        def invalid(response, person, params, errors)
          halt 404 unless person

          response.status = 422
          response.render(edit_view, **build_person_editor.call(person:, params:, errors:))
        end

        def saved(response)
          toast(response, SAVED)
          response.redirect_to(routes.path(:admin_people))
        end
      end
    end
  end
end
