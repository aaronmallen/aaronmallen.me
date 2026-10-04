# frozen_string_literal: true

module Admin
  module Actions
    module Commits
      class UnlinkRecord < Action
        KIND = Blog::Types::RecordKind["commit"]

        include RecordLinking
        include Deps[unlink_records: "links.operations.unlink_records"]

        def handle(request, response) = unlink(request, response)

        private

        def record_path(_request, id) = routes.path(:admin_commit, id:)
      end
    end
  end
end
