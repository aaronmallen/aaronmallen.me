# frozen_string_literal: true

module Admin
  module Actions
    module Commits
      class Show < Action
        include Deps[build_commit_page: "operations.build_commit_page"]

        def handle(request, response)
          page = build_commit_page.call(record_id(request), records: { query: request.params[:record_q] })
          not_found(response) unless page

          response.render(view, **page)
        end
      end
    end
  end
end
