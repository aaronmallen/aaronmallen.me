# frozen_string_literal: true

module Admin
  module Actions
    module People
      class Update < Action
        SAVED = "people_page.toasts.saved"

        include Deps[
          edit_view: "ui.views.people.edit",
          person_queries: "contacts.repos.person_queries",
          save_person: "contacts.operations.save_person",
        ]

        def handle(request, response)
          id = record_id(request)
          values = Helpers::ContactForm.read(request.params[:person])

          result = save_person.call(Helpers::ContactForm.fields(values), id:)

          settle(response, result, SAVED, routes.path(:admin_person, id:)) do |errors|
            invalid(response, person_queries.by_id(id), values, errors)
          end
        end

        private

        def invalid(response, person, values, errors)
          halt :not_found unless person

          errors = Helpers::ContactForm.errors(errors)
          unprocessable(response, edit_view, person:, values:, errors:, labels: person_queries.labels)
        end
      end
    end
  end
end
