# frozen_string_literal: true

module SavedViews
  module Operations
    class RenameSavedView < Operation
      include Deps[contract: "contracts.saved_view_contract", saved_view_repo: "repos.saved_view_repo"]

      def call(id, params)
        view = step find(id)
        fields = step validate(name: params[:name], screen: view.screen, filters: view.filters)

        saved_view_repo.update(view.id, name: fields[:name])
      end

      private

      def find(id)
        found(saved_view_repo.by_id(id))
      end

      def validate(form) = validated(contract.call(form))
    end
  end
end
