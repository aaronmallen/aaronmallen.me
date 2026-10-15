# frozen_string_literal: true

module Admin
  module Actions
    module Links
      class Check < Action
        CHECKING = "links_page.toasts.check"

        include Deps[queue_short_link_check: "shares.operations.queue_short_link_check"]

        def handle(request, response)
          id = record_id(request)
          back = back_here(request) || routes.path(:admin_edit_link, id:)

          settle(response, queue_short_link_check.call(id), CHECKING, back)
        end
      end
    end
  end
end
