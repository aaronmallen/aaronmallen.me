# frozen_string_literal: true

module Admin
  module Actions
    module Posts
      class UnlinkRecord < UnlinkRecordAction
        KIND = Blog::Types::RecordKind["post"]

        private

        def record_path(_request, id) = routes.path(:admin_edit_post, id:)
      end
    end
  end
end
