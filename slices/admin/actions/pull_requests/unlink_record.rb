# frozen_string_literal: true

module Admin
  module Actions
    module PullRequests
      class UnlinkRecord < Action
        KIND = Blog::Types::RecordKind["pull_request"]

        include RecordLinking
        include Deps[unlink_records: "links.operations.unlink_records"]

        def handle(request, response) = unlink(request, response)

        private

        def record_path(_request, id) = routes.path(:admin_pull_request, id:)
      end
    end
  end
end
