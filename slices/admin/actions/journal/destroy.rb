# frozen_string_literal: true

module Admin
  module Actions
    module Journal
      class Destroy < Action
        DELETED = "journal_page.toasts.deleted"

        include Deps[delete_journal_entry: "record.operations.delete_journal_entry"]

        def handle(request, response)
          back = auth_session(request).admin_return_path(request.params[:return_to]) || routes.path(:admin_journal)

          settle(response, delete_journal_entry.call(record_id(request)), DELETED, back)
        end
      end
    end
  end
end
