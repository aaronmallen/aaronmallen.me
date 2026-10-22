# frozen_string_literal: true

module Admin
  module Actions
    module People
      class Sync < Action
        QUEUED = "people_page.toasts.sync_queued"

        include Deps[queue_contact_sync: "contacts.operations.queue_contact_sync"]

        def handle(_request, response)
          toast(response, queue_contact_sync.call.success? ? QUEUED : QUEUE_UNAVAILABLE)
          response.redirect_to(routes.path(:admin_contacts))
        end
      end
    end
  end
end
