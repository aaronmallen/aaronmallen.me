# frozen_string_literal: true

module Admin
  module Actions
    module Decisions
      class LinkRecord < Action
        KIND = Blog::Types::RecordKind["decision"]
        LINKED = "decisions_page.toasts.record_linked"

        include PageForm
        include Deps[
          build_decision_page: "operations.build_decision_page",
          link_records: "links.operations.link_records",
          show_view: "ui.views.decisions.show",
        ]

        def handle(request, response)
          case link_records.call(KIND, record_id(request), Blog::Types::Fields[request.params[:record]])
          in Success(_) then to_decision(request, response, LINKED)
          in Failure(:not_found) then halt 404
          in Failure[:invalid, errors] then invalid(request, response, errors)
          else halt 500
          end
        end

        private

        def invalid(request, response, errors)
          page = build_decision_page.call(record_id(request), records: { query: request.params[:record_q], errors: })
          halt 404 unless page

          response.status = 422
          response.render(show_view, **page)
        end
      end
    end
  end
end
