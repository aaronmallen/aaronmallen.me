# frozen_string_literal: true

module Admin
  module Actions
    module People
      class Destroy < Action
        REMOVED = "people_page.toasts.removed"

        include Deps[delete_person: "contacts.operations.delete_person"]

        def handle(request, response)
          back = back_to_section(request, :admin_settings_webmentions, Helpers::WebmentionTab::PEOPLE) || Helpers::WebmentionTab.people(routes)
          settle(response, delete_person.call(record_id(request)), REMOVED, back)
        end
      end
    end
  end
end
