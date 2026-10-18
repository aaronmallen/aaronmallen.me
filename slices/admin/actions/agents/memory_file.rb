# frozen_string_literal: true

module Admin
  module Actions
    module Agents
      class MemoryFile < Action
        include Deps[build_memory_file_page: "operations.build_memory_file_page"]

        def handle(request, response)
          page = build_memory_file_page.call(
            record_id(request), view: request.params[:view], records: { query: request.params[:record_q] },
          )
          not_found(response) unless page

          response.render(view, **page)
        end
      end
    end
  end
end
