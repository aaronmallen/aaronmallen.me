# frozen_string_literal: true

module API
  module Actions
    module Tasks
      class Index < Action
        LISTED = %i[lists statuses].freeze
        SEPARATOR = ","

        include Deps[endpoint: "endpoints.list_tasks"]

        def handle(request, response) = answer(response, endpoint.call(listing(request)))

        private

        def listing(request)
          found = query(request, :from, :lists, :page, :query, :statuses, :tag, :to)
          pages = found.slice(:page).transform_values { whole(it) }
          listed = found.slice(*LISTED).transform_values { split(it) }

          found.merge(pages, listed)
        end

        def split(values) = values.is_a?(String) ? values.split(SEPARATOR) : values

        def whole(page) = Integer(page, 10, exception: false) || page
      end
    end
  end
end
