# frozen_string_literal: true

module Admin
  module Actions
    module Commits
      class Menu < Action
        include Deps[commit_queries: "record.repos.commit_queries"]

        def handle(request, response)
          response.render(view, commit: commit_queries.by_id(record_id(request)) || halt(:not_found))
        end
      end
    end
  end
end
