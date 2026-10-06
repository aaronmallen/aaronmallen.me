# frozen_string_literal: true

module Admin
  module Actions
    module Tasks
      class UnlinkRecord < Action
        KIND = Blog::Types::RecordKind["task"]
        UNLINKED = "tasks_page.toasts.record_unlinked"

        include Redirect
        include RecordLinking
        include Deps[unlink_records: "links.operations.unlink_records"]

        def handle(request, response) = unlink(request, response)

        private

        def record_path(request, _id) = tasks_path(request)
      end
    end
  end
end
