# frozen_string_literal: true

module Admin
  module Actions
    module Projects
      class UnlinkRecord < UnlinkRecordAction
        KIND = Blog::Types::RecordKind["project"]

        private

        def record_path(_request, id) = routes.path(:admin_edit_project, id:)
      end
    end
  end
end
