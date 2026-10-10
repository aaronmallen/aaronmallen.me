# frozen_string_literal: true

module SavedViews
  module Operations
    class CreateSavedView < Blog::Operation
      include Deps[
        contract: "contracts.saved_view_contract",
        filters_contract: "contracts.filters_contract",
        saved_view_mutations: "repos.saved_view_mutations",
      ]

      def call(params)
        fields = step validate(params)

        saved_view_mutations.create(**fields)
      end

      private

      def form(params)
        screen = params[:screen]

        { name: params[:name], screen:, filters: kept(screen, params[:filters]) }
      end

      def kept(screen, filters) = filters_contract.call(screen:, filters:).to_h[:filters]

      def validate(params) = validated(contract.call(form(params)))
    end
  end
end
