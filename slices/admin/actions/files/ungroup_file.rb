# frozen_string_literal: true

module Admin
  module Actions
    module Files
      class UngroupFile < Action
        UNGROUPED = "files_page.toasts.ungrouped"

        include Deps[ungroup_share_file: "shares.operations.ungroup_share_file"]

        def handle(request, response)
          result = ungroup_share_file.call(record_id(request), record_id(request, :file_id))

          settle(response, result, UNGROUPED, routes.path(:admin_files))
        end
      end
    end
  end
end
