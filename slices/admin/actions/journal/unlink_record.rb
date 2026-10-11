# frozen_string_literal: true

module Admin
  module Actions
    module Journal
      class UnlinkRecord < UnlinkRecordAction
        KIND = Blog::Types::RecordKind["journal_entry"]

        private

        def record_path(request, id)
          routes.path(:admin_journal, to: Blog::Types::DateParam[request.params[:to]], edit: id)
        end
      end
    end
  end
end
