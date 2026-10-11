# frozen_string_literal: true

module Admin
  module Actions
    module Tasks
      class UnlinkRecord < UnlinkRecordAction
        KIND = Blog::Types::RecordKind["task"]
        UNLINKED = "tasks_page.toasts.record_unlinked"

        include Redirect

        private

        def record_path(request, _id) = tasks_path(request)
      end
    end
  end
end
