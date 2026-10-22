# frozen_string_literal: true

module Admin
  module Actions
    module People
      class Create < Action
        ADDED = "people_page.toasts.added"
        MENTION = "mention"

        include Deps[
          build_person_editor: "operations.build_person_editor",
          mention_view: "ui.views.people.mention",
          new_view: "ui.views.people.new",
          resolve_mentions: "social.operations.resolve_mentions",
          save_person: "contacts.operations.save_person",
        ]

        def handle(request, response)
          params = Blog::Types::Fields[request.params[:person]]

          case save_person.call(params)
            in Success(person) then added(request, response, person)
            in Failure[:invalid, errors]
              unprocessable(response, new_view, **build_person_editor.call(params:, errors:))
          end
        end

        private

        def added(request, response, person)
          return mention(response, person) if request.params[:reply] == MENTION

          toast(response, ADDED)
          response.redirect_to(Helpers::WebmentionTab.people(routes))
        end

        def mention(response, person)
          response.status = :created
          response.render(mention_view, handles: resolve_mentions.handles([person]), person:)
        end
      end
    end
  end
end
