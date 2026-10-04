# frozen_string_literal: true

module Admin
  module Actions
    module Journal
      class UnlinkRecord < Action
        KIND = Blog::Types::RecordKind["journal_entry"]

        include RecordLinking
        include Deps[unlink_records: "links.operations.unlink_records"]

        def handle(request, response) = unlink(request, response)

        private

        def record_path(request, id)
          routes.path(:admin_journal, to: Blog::Types::DateParam[request.params[:to]], edit: id)
        end
      end
    end
  end
end
