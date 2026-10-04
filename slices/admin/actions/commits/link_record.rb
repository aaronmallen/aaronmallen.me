# frozen_string_literal: true

module Admin
  module Actions
    module Commits
      class LinkRecord < Action
        KIND = Blog::Types::RecordKind["commit"]

        include RecordLinking
        include Deps[
          build_commit_page: "operations.build_commit_page",
          link_records: "links.operations.link_records",
          show_view: "ui.views.commits.show",
        ]

        def handle(request, response) = link(request, response)

        private

        def record_path(_request, id) = routes.path(:admin_commit, id:)

        def render_refused(request, response, id, errors)
          page = build_commit_page.call(id, records: records_query(request, errors))
          halt 404 unless page

          response.render(show_view, **page)
        end
      end
    end
  end
end
