# frozen_string_literal: true

module Admin
  module Actions
    module Journal
      class Destroy < Action
        DELETED = "journal_page.toasts.deleted"

        include Deps[delete_journal_entry: "record.operations.delete_journal_entry"]

        def handle(request, response)
          case delete_journal_entry.call(record_id(request))
          in Success(_)
            toast(response, DELETED)
            response.redirect_to(routes.path(:admin_journal))
          in Failure(:not_found)
            halt 404
          else halt 500
          end
        end
      end
    end
  end
end
