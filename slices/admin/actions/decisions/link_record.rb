# frozen_string_literal: true

module Admin
  module Actions
    module Decisions
      class LinkRecord < LinkRecordAction
        KIND = Blog::Types::RecordKind["decision"]
        LINKED = "decisions_page.toasts.record_linked"

        include Deps[
          build_decision_page: "operations.build_decision_page",
          show_view: "ui.views.decisions.show",
        ]

        private

        def record_path(_request, id) = routes.path(:admin_decision, id:)

        def render_refused(request, response, id, errors)
          page = build_decision_page.call(id, records: records_query(request, errors))
          halt 404 unless page

          response.render(show_view, **page)
        end
      end
    end
  end
end
