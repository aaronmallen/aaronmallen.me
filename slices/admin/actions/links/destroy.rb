# frozen_string_literal: true

module Admin
  module Actions
    module Links
      class Destroy < Action
        DELETED = "links_page.toasts.deleted"

        include Deps[delete_short_link: "shares.operations.delete_short_link"]

        def handle(request, response)
          back = back_here(request) || routes.path(:admin_links)

          settle(response, delete_short_link.call(record_id(request)), DELETED, back)
        end
      end
    end
  end
end
