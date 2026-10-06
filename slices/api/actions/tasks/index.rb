# frozen_string_literal: true

module API
  module Actions
    module Tasks
      class Index < Action
        LISTED = %i[lists statuses].freeze

        include Deps[endpoint: "endpoints.list_tasks"]

        def handle(request, response) = answer(response, endpoint.call(listing(request)))

        private

        def listing(request)
          found = paged_query(request, :from, :lists, :query, :sprint_on, :statuses, :tag, :to)

          found.merge(found.slice(*LISTED).transform_values { split(it) })
        end
      end
    end
  end
end
