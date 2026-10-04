# frozen_string_literal: true

module Admin
  module Actions
    module Projects
      class UnlinkWorkRecord < Action
        KIND = Blog::Types::RecordKind["work_entry"]
        WORK = Blog::Types::ProjectFilter["work"]

        include RecordLinking
        include Deps[unlink_records: "links.operations.unlink_records"]

        def handle(request, response) = unlink(request, response)

        private

        def record_path(_request, id) = routes.path(:admin_projects, filter: WORK, edit: id)
      end
    end
  end
end
