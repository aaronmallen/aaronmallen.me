# frozen_string_literal: true

module Admin
  module Actions
    module Files
      class Destroy < Action
        DELETED = "files_page.toasts.deleted"
        UNAVAILABLE = "files_page.toasts.failed.delete"

        include Deps[delete_share: "shares.operations.delete_share"]

        def handle(request, response)
          case delete_share.call(record_id(request))
            in Failure[:unavailable]
              toast(response, UNAVAILABLE)
              response.redirect_to(routes.path(:admin_files))
            in result then settle(response, result, DELETED, routes.path(:admin_files))
          end
        end
      end
    end
  end
end
