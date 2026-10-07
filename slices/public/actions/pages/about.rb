# frozen_string_literal: true

module Public
  module Actions
    module Pages
      class About < Action
        include Deps[work_entry_queries: "projects.repos.work_entry_queries"]

        share_with_caches

        def handle(_request, response)
          response[:work_entries] = work_entry_queries.all
        end
      end
    end
  end
end
