# frozen_string_literal: true

module SavedViews
  module Operations
    class ChangeSavedView < Blog::Operation
      include Deps[contract: "contracts.saved_view_contract", saved_view_repo: "repos.saved_view_repo"]

      def call(id, params)
        view = step find(id)
        fields = step validate(form(view, params))

        saved_view_repo.update(view.id, filters: fields[:filters])
      end

      private

      def find(id)
        view = saved_view_repo.by_id(id)

        view ? Success(view) : Failure(:not_found)
      end

      def form(view, params)
        { name: view.name, screen: view.screen, filters: Filters.keep(view.screen, params[:filters]) }
      end

      def validate(form) = validated(contract.call(form))
    end
  end
end
