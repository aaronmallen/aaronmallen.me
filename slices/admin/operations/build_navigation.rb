# frozen_string_literal: true

module Admin
  module Operations
    class BuildNavigation
      include Deps["operations.list_sections", open_tasks: "tasks.queries.open_tasks"]

      def call(current_path:)
        Structs::Navigation.new(sections: list_sections.call(current_path:), tasks: open_tasks.call)
      end
    end
  end
end
