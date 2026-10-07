# frozen_string_literal: true

module Admin
  module Actions
    module People
      class Create < Action
        ADDED = "people_page.toasts.added"
        CREATED = 201
        MENTION = "mention"

        include Deps[
          build_person_editor: "operations.build_person_editor",
          mention_view: "ui.views.people.mention",
          new_view: "ui.views.people.new",
          save_person: "social.operations.save_person",
        ]

        def handle(request, response)
          params = Blog::Types::Fields[request.params[:person]]

          case save_person.call(params)
            in Success(person) then added(request, response, person)
            in Failure[:invalid, errors]
              response.status = 422
              response.render(new_view, **build_person_editor.call(params:, errors:))
            else halt 500
          end
        end

        private

        def added(request, response, person)
          return mention(response, person) if request.params[:reply] == MENTION

          toast(response, ADDED)
          response.redirect_to(routes.path(:admin_people))
        end

        def mention(response, person)
          response.status = CREATED
          response.render(mention_view, person:)
        end
      end
    end
  end
end
