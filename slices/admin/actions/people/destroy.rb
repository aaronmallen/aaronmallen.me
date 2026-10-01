# frozen_string_literal: true

module Admin
  module Actions
    module People
      class Destroy < Action
        REMOVED = "people_page.toasts.removed"

        include Deps[delete_person: "social.operations.delete_person"]

        def handle(request, response)
          case delete_person.call(record_id(request))
          in Success(_)
            toast(response, REMOVED)
            response.redirect_to(routes.path(:admin_people))
          in Failure(:not_found)
            halt 404
          else halt 500
          end
        end
      end
    end
  end
end
