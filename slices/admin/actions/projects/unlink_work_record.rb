# frozen_string_literal: true

module Admin
  module Actions
    module Projects
      class UnlinkWorkRecord < UnlinkRecordAction
        KIND = Blog::Types::RecordKind["work_entry"]
        WORK = Blog::Types::ProjectFilter["work"]

        private

        def record_path(_request, id) = routes.path(:admin_projects, filter: WORK, edit: id)
      end
    end
  end
end
