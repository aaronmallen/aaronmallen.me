# frozen_string_literal: true

module Admin
  module Actions
    module PullRequests
      class Show < Action
        include Deps[build_pull_request_page: "operations.build_pull_request_page"]

        def handle(request, response)
          page = build_pull_request_page.call(record_id(request))
          not_found(response) unless page

          response.render(view, **page)
        end
      end
    end
  end
end
