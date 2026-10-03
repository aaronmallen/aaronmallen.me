# frozen_string_literal: true

module SavedViews
  module Operations
    class RenameSavedView < Blog::Operation
      include Deps[contract: "contracts.saved_view_contract", saved_view_repo: "repos.saved_view_repo"]

      def call(id, params)
        view = step find(id)
        fields = step validate(name: params[:name], screen: view.screen, filters: view.filters)

        saved_view_repo.update(view.id, name: fields[:name])
      end

      private

      def find(id)
        view = saved_view_repo.by_id(id)

        view ? Success(view) : Failure(:not_found)
      end

      def validate(form) = validated(contract.call(form))
    end
  end
end
