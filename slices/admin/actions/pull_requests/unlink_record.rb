# frozen_string_literal: true

module Admin
  module Actions
    module PullRequests
      class UnlinkRecord < UnlinkRecordAction
        KIND = Blog::Types::RecordKind["pull_request"]

        private

        def record_path(_request, id) = routes.path(:admin_pull_request, id:)
      end
    end
  end
end
