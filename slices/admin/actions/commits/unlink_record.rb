# frozen_string_literal: true

module Admin
  module Actions
    module Commits
      class UnlinkRecord < UnlinkRecordAction
        KIND = Blog::Types::RecordKind["commit"]

        private

        def record_path(_request, id) = routes.path(:admin_commit, id:)
      end
    end
  end
end
