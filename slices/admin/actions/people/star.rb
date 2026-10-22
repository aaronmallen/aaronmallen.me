# frozen_string_literal: true

module Admin
  module Actions
    module People
      class Star < Action
        CONFLICT = "people_page.toasts.conflict"
        GOOGLE_FAILED = "people_page.toasts.google_failed"
        STARRED = { true => "people_page.toasts.starred", false => "people_page.toasts.unstarred" }.freeze

        include Deps[save_person: "contacts.operations.save_person"]

        def handle(request, response)
          id = record_id(request)
          starred = request.params[:starred] == Blog::Constants::CHECKED

          back = routes.path(:admin_person, id:)

          case save_person.call({ starred: }, id:)
            in Failure(:conflict) then toast_back(response, CONFLICT, back)
            in Failure[:google_failed, _] then toast_back(response, GOOGLE_FAILED, back)
            in result then settle(response, result, STARRED.fetch(starred), back)
          end
        end
      end
    end
  end
end
