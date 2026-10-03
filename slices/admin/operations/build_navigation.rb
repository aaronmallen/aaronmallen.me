# frozen_string_literal: true

module Admin
  module Operations
    class BuildNavigation
      include Deps["operations.list_actions", "operations.list_sections"]

      def call(current_path:)
        Structs::Navigation.new(
          sections: list_sections.call(current_path:), actions: list_actions.call(current_path:),
        )
      end
    end
  end
end
