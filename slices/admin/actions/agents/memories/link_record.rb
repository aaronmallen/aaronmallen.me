# frozen_string_literal: true

module Admin
  module Actions
    module Agents
      module Memories
        class LinkRecord < LinkRecordAction
          KIND = Blog::Types::RecordKind["memory_file"]

          include Deps[
            build_memory_file_page: "operations.build_memory_file_page",
            memory_file_view: "ui.views.agents.memory_file",
          ]

          private

          def record_path(_request, id) = routes.path(:admin_memory_file, id:)

          def render_refused(request, response, id, errors)
            page = build_memory_file_page.call(id, records: records_query(request, errors))
            halt :not_found unless page

            unprocessable(response, memory_file_view, **page)
          end
        end
      end
    end
  end
end
