# frozen_string_literal: true

module Admin
  module Actions
    module Files
      class RemoveGroupFile < Action
        REMOVED = "files_page.toasts.removed"
        UNAVAILABLE = "files_page.toasts.failed.delete"

        include Deps[remove_share_group_file: "shares.operations.remove_share_group_file"]

        def handle(request, response)
          back = routes.path(:admin_files)
          file_id = Blog::Types::IdParam[request.params[:file_id]] || halt(404)

          case remove_share_group_file.call(record_id(request), file_id)
            in Failure[:unavailable]
              toast(response, UNAVAILABLE)
              response.redirect_to(back)
            in result then settle(response, result, REMOVED, back)
          end
        end
      end
    end
  end
end
