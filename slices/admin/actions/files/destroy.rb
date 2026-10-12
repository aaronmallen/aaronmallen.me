# frozen_string_literal: true

module Admin
  module Actions
    module Files
      class Destroy < Action
        DELETED = "files_page.toasts.deleted"
        UNAVAILABLE = "files_page.toasts.failed.delete"

        include Deps[delete_share: "shares.operations.delete_share"]

        def handle(request, response)
          back = auth_session(request).admin_return_path(request.params[:return_to]) || routes.path(:admin_files)

          case delete_share.call(record_id(request))
            in Failure[:unavailable]
              toast(response, UNAVAILABLE)
              response.redirect_to(back)
            in result then settle(response, result, DELETED, back)
          end
        end
      end
    end
  end
end
