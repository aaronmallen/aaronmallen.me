# frozen_string_literal: true

module SavedViews
  module Operations
    class CreateSavedView < Operation
      include Deps[contract: "contracts.saved_view_contract", saved_view_repo: "repos.saved_view_repo"]

      def call(params)
        fields = step validate(params)

        saved_view_repo.create(**fields)
      end

      private

      def form(params)
        screen = params[:screen]

        { name: params[:name], screen:, filters: Filters.keep(screen, params[:filters]) }
      end

      def validate(params) = validated(contract.call(form(params)))
    end
  end
end
