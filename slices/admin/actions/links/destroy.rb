# frozen_string_literal: true

module Admin
  module Actions
    module Links
      class Destroy < Action
        DELETED = "links_page.toasts.deleted"

        include Deps[delete_short_link: "shares.operations.delete_short_link"]

        def handle(request, response)
          back = auth_session(request).admin_return_path(request.params[:return_to]) || routes.path(:admin_links)

          settle(response, delete_short_link.call(record_id(request)), DELETED, back)
        end
      end
    end
  end
end
