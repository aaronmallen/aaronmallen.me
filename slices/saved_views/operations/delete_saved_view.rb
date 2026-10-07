# frozen_string_literal: true

module SavedViews
  module Operations
    class DeleteSavedView < Operation
      include Deps[saved_view_mutations: "repos.saved_view_mutations", saved_view_queries: "repos.saved_view_queries"]

      def call(id)
        view = step find(id)

        saved_view_mutations.delete(view.id)
      end

      private

      def find(id)
        found(saved_view_queries.by_id(id))
      end
    end
  end
end
