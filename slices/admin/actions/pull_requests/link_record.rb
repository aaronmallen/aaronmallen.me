# frozen_string_literal: true

module Admin
  module Actions
    module PullRequests
      class LinkRecord < Action
        KIND = Blog::Types::RecordKind["pull_request"]

        include RecordLinking
        include Deps[
          build_pull_request_page: "operations.build_pull_request_page",
          link_records: "links.operations.link_records",
          show_view: "ui.views.pull_requests.show",
        ]

        def handle(request, response) = link(request, response)

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
