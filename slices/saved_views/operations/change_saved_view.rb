# frozen_string_literal: true

module SavedViews
  module Operations
    class ChangeSavedView < Operation
      include Deps[
        contract: "contracts.saved_view_contract",
        saved_view_mutations: "repos.saved_view_mutations",
        saved_view_queries: "repos.saved_view_queries",
      ]

      def call(id, params)
        view = step find(id)
        fields = step validate(form(view, params))

        saved_view_mutations.update(view.id, **fields.slice(:name, :filters))
      end

      private

      def find(id)
        found(saved_view_queries.by_id(id))
      end

      def form(view, params)
        screen = view.screen

        { name: params.fetch(:name, view.name), screen:, filters: Filters.keep(screen, params[:filters]) }
      end

      def validate(form) = validated(contract.call(form))
    end
  end
end
