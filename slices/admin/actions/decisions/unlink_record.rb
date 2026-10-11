# frozen_string_literal: true

module Admin
  module Actions
    module Decisions
      class UnlinkRecord < UnlinkRecordAction
        KIND = Blog::Types::RecordKind["decision"]
        UNLINKED = "decisions_page.toasts.record_unlinked"

        private

        def record_path(_request, id) = routes.path(:admin_decision, id:)
      end
    end
  end
end
