# frozen_string_literal: true

module Admin
  module Actions
    module Agents
      class MemoryFile < Action
        include Deps[build_memory_file_page: "operations.build_memory_file_page"]

        def handle(request, response)
          page = build_memory_file_page.call(
            record_id(request),
            page: requested_page(request, response), view: request.params[:view],
            records: { query: request.params[:record_q] },
          )
          not_found(response) if page.nil? || page[:history].past_end?

          response.render(view, **page)
        end
      end
    end
  end
end
