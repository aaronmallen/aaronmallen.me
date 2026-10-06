# frozen_string_literal: true

module Admin
  module Actions
    module Decisions
      class UnlinkRecord < Action
        KIND = Blog::Types::RecordKind["decision"]
        UNLINKED = "decisions_page.toasts.record_unlinked"

        include RecordLinking
        include Deps[unlink_records: "links.operations.unlink_records"]

        def handle(request, response) = unlink(request, response)

        private

        def record_path(_request, id) = routes.path(:admin_decision, id:)
      end
    end
  end
end
