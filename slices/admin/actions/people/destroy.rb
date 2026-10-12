# frozen_string_literal: true

module Admin
  module Actions
    module People
      class Destroy < Action
        REMOVED = "people_page.toasts.removed"

        include Deps[delete_person: "social.operations.delete_person"]

        def handle(request, response)
          back = back_here(request) || routes.path(:admin_people)
          settle(response, delete_person.call(record_id(request)), REMOVED, back)
        end
      end
    end
  end
end
