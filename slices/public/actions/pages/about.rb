# frozen_string_literal: true

module Public
  module Actions
    module Pages
      class About < Action
        include Deps[all_work_entries: "projects.queries.work_entries"]

        def handle(_request, response)
          response[:work_entries] = all_work_entries.call
        end
      end
    end
  end
end
