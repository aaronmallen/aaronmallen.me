# frozen_string_literal: true

module Admin
  module Actions
    module People
      class Destroy < Action
        GOOGLE_FAILED = "people_page.toasts.google_failed"
        REMOVED = "people_page.toasts.removed"

        include Deps[delete_person: "contacts.operations.delete_person"]

        def handle(request, response)
          back = back_here(request) || routes.path(:admin_contacts)
          case delete_person.call(record_id(request))
            in Failure[:google_failed, _] then toast_back(response, GOOGLE_FAILED, back)
            in result then settle(response, result, REMOVED, back)
          end
        end
      end
    end
  end
end
