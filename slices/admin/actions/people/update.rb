# frozen_string_literal: true

module Admin
  module Actions
    module People
      class Update < Action
        CONFLICT = "people_page.toasts.conflict"
        GOOGLE_FAILED = "people_page.toasts.google_failed"
        SAVED = "people_page.toasts.saved"

        include Deps[
          edit_view: "ui.views.people.edit",
          person_queries: "contacts.repos.person_queries",
          save_person: "contacts.operations.save_person",
        ]

        def handle(request, response)
          id = record_id(request)
          values = Helpers::ContactForm.read(request.params[:person])

          settled(response, save_person.call(Helpers::ContactForm.fields(values), id:), id, values)
        end

        private

        def conflicted(response, person)
          refused(response, person, Helpers::ContactForm.values(person), alert: i18n.t!(CONFLICT))
        end

        def refused(response, person, values, errors: Blog::Constants::EMPTY_HASH, alert: nil)
          halt :not_found unless person

          unprocessable(response, edit_view, person:, values:, errors:, labels: person_queries.labels, alert:)
        end

        def settled(response, result, id, values)
          case result
            in Failure(:conflict) then conflicted(response, person_queries.by_id(id))
            in Failure[:google_failed, _]
              refused(response, person_queries.by_id(id), values, alert: i18n.t!(GOOGLE_FAILED))
            in result
              settle(response, result, SAVED, routes.path(:admin_person, id:)) do |errors|
                refused(response, person_queries.by_id(id), values, errors: Helpers::ContactForm.errors(errors))
              end
          end
        end
      end
    end
  end
end
