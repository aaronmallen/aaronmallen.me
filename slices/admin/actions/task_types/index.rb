# frozen_string_literal: true

module Admin
  module Actions
    module TaskTypes
      class Index < Action
        include Deps[build_task_types_page: "operations.build_task_types_page"]

        def handle(_request, response)
          response.render(view, **build_task_types_page.call)
        end
      end
    end
  end
end
