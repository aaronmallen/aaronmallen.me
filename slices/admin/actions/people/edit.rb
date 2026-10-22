# frozen_string_literal: true

module Admin
  module Actions
    module People
      class Edit < Action
        include Deps[person_queries: "contacts.repos.person_queries"]

        def handle(request, response)
          person = person_queries.by_id(record_id(request))
          not_found(response) unless person

          response.render(
            view, person:, values: Helpers::ContactForm.values(person), errors: Blog::Constants::EMPTY_HASH,
                  labels: person_queries.labels,
          )
        end
      end
    end
  end
end
