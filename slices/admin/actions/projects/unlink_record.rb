# frozen_string_literal: true

module Admin
  module Actions
    module Projects
      class UnlinkRecord < Action
        KIND = Blog::Types::RecordKind["project"]

        include RecordLinking
        include Deps[unlink_records: "links.operations.unlink_records"]

        def handle(request, response) = unlink(request, response)

        private

        def record_path(_request, id) = routes.path(:admin_edit_project, id:)
      end
    end
  end
end
