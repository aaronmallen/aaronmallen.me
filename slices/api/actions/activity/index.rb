# frozen_string_literal: true

module API
  module Actions
    module Activity
      class Index < Action
        include Deps[endpoint: "endpoints.read_activity"]

        def handle(request, response) = answer(response, endpoint.call(listing(request)))

        private

        def listing(request)
          found = query(request, :from, :to, :kinds, :repos, :tags, :text, :contributor, :agent, :model)

          found.merge(found.slice(:kinds, :repos, :tags).transform_values { split(it) })
        end
      end
    end
  end
end
