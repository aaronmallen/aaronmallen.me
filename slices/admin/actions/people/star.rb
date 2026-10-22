# frozen_string_literal: true

module Admin
  module Actions
    module People
      class Star < Action
        STARRED = { true => "people_page.toasts.starred", false => "people_page.toasts.unstarred" }.freeze

        include Deps[save_person: "contacts.operations.save_person"]

        def handle(request, response)
          id = record_id(request)
          starred = request.params[:starred] == Blog::Constants::CHECKED

          settle(response, save_person.call({ starred: }, id:), STARRED.fetch(starred), routes.path(:admin_person, id:))
        end
      end
    end
  end
end
