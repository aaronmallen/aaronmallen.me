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
          new_mention_view: "ui.views.people.new_mention",
          new_view: "ui.views.people.new",
          person_queries: "contacts.repos.person_queries",
          resolve_mentions: "social.operations.resolve_mentions",
          save_person: "contacts.operations.save_person",
        ]

        def self.mention?(request) = request.params[:reply] == MENTION

        def handle(request, response)
          self.class.mention?(request) ? from_composer(request, response) : from_page(request, response)
        end

        private

        def from_composer(request, response)
          params = Blog::Types::Fields[request.params[:person]]

          case save_person.call(params)
            in Success(person)
              response.status = :created
              response.render(mention_view, handles: resolve_mentions.handles([person]), person:)
            in Failure[:invalid, errors]
              unprocessable(response, new_mention_view, **build_person_editor.call(params:, errors:))
          end
        end

        def from_page(request, response)
          values = Helpers::ContactForm.read(request.params[:person])

          case save_person.call(Helpers::ContactForm.fields(values))
            in Success(person) then toast_back(response, ADDED, routes.path(:admin_person, id: person.id))
            in Failure[:invalid, errors]
              unprocessable(
                response, new_view, values:, errors: Helpers::ContactForm.errors(errors), labels: person_queries.labels,
              )
          end
        end
      end
    end
  end
end
