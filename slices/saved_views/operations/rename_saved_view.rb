# frozen_string_literal: true

module SavedViews
  module Operations
    class RenameSavedView < Operation
      include Deps[
        contract: "contracts.saved_view_contract",
        saved_view_mutations: "repos.saved_view_mutations",
        saved_view_queries: "repos.saved_view_queries",
      ]

      def call(id, params)
        view = step find(id)
        fields = step validate(name: params[:name], screen: view.screen, filters: view.filters)

        saved_view_mutations.update(view.id, name: fields[:name])
      end

      private

      def find(id)
        found(saved_view_queries.by_id(id))
      end

      def validate(form) = validated(contract.call(form))
    end
  end
end
