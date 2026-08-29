# frozen_string_literal: true

module Public
  module Actions
    module Pages
      class Projects < Action
        include Deps[public_project_grid: "projects.queries.public_grid"]

        def handle(_request, response)
          response[:projects] = public_project_grid.call
        end
      end
    end
  end
end
