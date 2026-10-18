# auto_register: false
# frozen_string_literal: true

module Admin
  module Actions
    module Agents
      class MemoryFileAction < Action
        OWNER = { agent: nil, model: nil, session_id: nil }.freeze
        STALE = "memories_page.toasts.stale"

        include Deps[
          build_memory_file_page: "operations.build_memory_file_page", memory_file_view: "ui.views.agents.memory_file",
        ]

        private

        def fact_fields(request) = Blog::Types::Fields[request.params[:fact]].slice(:type, :text)

        def file_path(request) = routes.path(:admin_agent_memory_file, id: record_id(request))

        def refuse(request, response, form)
          page = build_memory_file_page.call(record_id(request), form:)
          halt :not_found unless page

          unprocessable(response, memory_file_view, **page)
        end

        def written(request, response, result, key, form = nil)
          case result
            in Success(_) then toast_back(response, key, file_path(request))
            in Failure[:invalid, errors] if form then refuse(request, response, { **form, errors: })
            in Failure(:not_found | :removed) then halt :not_found
            in Failure(:unrevertible) | Failure[:changed, _] then toast_back(response, STALE, file_path(request))
            else halt :internal_server_error
          end
        end
      end
    end
  end
end
