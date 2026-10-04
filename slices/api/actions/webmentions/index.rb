# frozen_string_literal: true

module API
  module Actions
    module Webmentions
      class Index < Action
        include Deps[endpoint: "endpoints.list_webmentions"]

        def handle(request, response) = answer(response, endpoint.call(listing(request)))

        private

        def listing(request)
          found = paged_query(request, :from, :to, :status, :post_id)
          found.key?(:post_id) ? found.merge(post_id: number(found[:post_id])) : found
        end
      end
    end
  end
end
