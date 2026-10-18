# frozen_string_literal: true

module Admin
  module Actions
    module Agents
      module Artifacts
        class LinkRecord < LinkRecordAction
          KIND = Blog::Types::RecordKind["artifact"]

          include Deps[
            build_artifact_page: "operations.build_artifact_page", show_view: "ui.views.agents.artifacts.show",
          ]

          private

          def record_path(_request, id) = routes.path(:admin_artifact, id:)

          def render_refused(request, response, id, errors)
            page = build_artifact_page.call(id, records: records_query(request, errors))
            halt :not_found unless page

            unprocessable(response, show_view, **page)
          end
        end
      end
    end
  end
end
