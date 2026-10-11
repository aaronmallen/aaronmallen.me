# frozen_string_literal: true

module Admin
  module Actions
    module PullRequests
      class LinkRecord < LinkRecordAction
        KIND = Blog::Types::RecordKind["pull_request"]

        include Deps[
          build_pull_request_page: "operations.build_pull_request_page",
          show_view: "ui.views.pull_requests.show",
        ]

        private

        def record_path(_request, id) = routes.path(:admin_pull_request, id:)

        def render_refused(request, response, id, errors)
          page = build_pull_request_page.call(id, records: records_query(request, errors))
          halt 404 unless page

          response.render(show_view, **page)
        end
      end
    end
  end
end
