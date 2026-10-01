# frozen_string_literal: true

module API
  module Actions
    module Tasks
      class Index < Action
        STATUS_SEPARATOR = ","

        include Deps[endpoint: "endpoints.list_tasks"]

        def handle(request, response) = answer(response, endpoint.call(listing(request)))

        private

        def listing(request)
          found = query(request, :from, :page, :statuses, :to)
          pages = found.slice(:page).transform_values { whole(it) }
          statuses = found.slice(:statuses).transform_values { split(it) }

          found.merge(pages, statuses)
        end

        def split(statuses) = statuses.is_a?(String) ? statuses.split(STATUS_SEPARATOR) : statuses

        def whole(page) = Integer(page, 10, exception: false) || page
      end
    end
  end
end
