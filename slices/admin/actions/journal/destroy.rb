# frozen_string_literal: true

module Admin
  module Actions
    module Journal
      class Destroy < Action
        DELETED = "journal_page.toasts.deleted"

        include Deps[delete_journal_entry: "record.operations.delete_journal_entry"]

        def handle(request, response)
          back = back_here(request) || routes.path(:admin_journal)

          settle(response, delete_journal_entry.call(record_id(request)), DELETED, back)
        end
      end
    end
  end
end
