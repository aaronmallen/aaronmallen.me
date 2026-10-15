# frozen_string_literal: true

module Admin
  module Operations
    class BuildNavigation
      include Deps["operations.list_actions", "operations.list_sections", inbox_queries: "api.repos.inbox_queries"]

      def call(current_path:)
        inbox = inbox_queries.unseen_counts

        Structs::Navigation.new(
          sections: list_sections.call(current_path:, inbox: inbox.values.sum), actions: list_actions.call, inbox:,
        )
      end
    end
  end
end
