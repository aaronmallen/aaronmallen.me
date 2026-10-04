# frozen_string_literal: true

module Admin
  module Actions
    module Projects
      class LinkWorkRecord < Action
        KIND = Blog::Types::RecordKind["work_entry"]
        WORK = Blog::Types::ProjectFilter["work"]

        include RecordLinking
        include Deps[
          build_projects_page: "operations.build_projects_page",
          index_view: "ui.views.projects.index",
          link_records: "links.operations.link_records",
        ]

        def handle(request, response) = link(request, response)

        private

        def record_path(_request, id) = routes.path(:admin_projects, filter: WORK, edit: id)

        def render_refused(request, response, id, errors)
          page = build_projects_page.call(filter: WORK, linking: id, records: records_query(request, errors))
          halt 404 unless page[:work_links]

          response.render(index_view, **page)
        end
      end
    end
  end
end
