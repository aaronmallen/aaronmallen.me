# frozen_string_literal: true

module Admin
  module Actions
    module Journal
      class Destroy < Action
        DELETED = "journal_page.toasts.deleted"

        include Deps[delete_journal_entry: "record.operations.delete_journal_entry"]

        def handle(request, response)
          settle(response, delete_journal_entry.call(record_id(request)), DELETED, routes.path(:admin_journal))
        end
      end
    end
  end
end
