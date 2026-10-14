# frozen_string_literal: true

module Admin
  module Actions
    module Files
      class DestroyGroup < Action
        DELETED = "files_page.toasts.group_deleted"
        UNAVAILABLE = "files_page.toasts.failed.delete"

        include Deps[delete_share_group: "shares.operations.delete_share_group"]

        def handle(request, response)
          back = routes.path(:admin_files)

          case delete_share_group.call(record_id(request))
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
