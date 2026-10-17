# frozen_string_literal: true

module Admin
  module Actions
    module Journal
      class Destroy < Action
        DELETED = "journal_page.toasts.deleted"

        include Deps[delete_journal_entry: "record.operations.delete_journal_entry"]

        def handle(request, response)
          back = back_here(request) || routes.path(:admin_journal, **place(request.params))

          settle(response, delete_journal_entry.call(record_id(request)), DELETED, back)
        end

        private

        def place(params)
          to = Blog::Types::DateParam[params[:to]]
          search = Blog::Types::TrimmedText[params[:q]]
          { to:, q: (search unless search.empty?) }.compact
        end
      end
    end
  end
end
