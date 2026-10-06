# frozen_string_literal: true

module Admin
  module Actions
    module People
      class Destroy < Action
        REMOVED = "people_page.toasts.removed"

        include Deps[delete_person: "social.operations.delete_person"]

        def handle(request, response)
          settle(response, delete_person.call(record_id(request)), REMOVED, routes.path(:admin_people))
        end
      end
    end
  end
end
