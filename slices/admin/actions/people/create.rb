# frozen_string_literal: true

module Admin
  module Actions
    module People
      class Create < Action
        ADDED = "people_page.toasts.added"

        include Deps[
          build_person_editor: "operations.build_person_editor",
          new_view: "ui.views.people.new",
          save_person: "social.operations.save_person",
        ]

        def handle(request, response)
          params = Blog::Types::Fields[request.params[:person]]

          case save_person.call(params)
          in Success(_)
            toast(response, ADDED)
            response.redirect_to(routes.path(:admin_people))
          in Failure[:invalid, errors]
            response.status = 422
            response.render(new_view, **build_person_editor.call(params:, errors:))
          else halt 500
          end
        end
      end
    end
  end
end
