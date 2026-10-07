# frozen_string_literal: true

module SavedViews
  module Operations
    class DeleteSavedView < Operation
      include Deps[saved_view_repo: "repos.saved_view_repo"]

      def call(id)
        view = step find(id)

        saved_view_repo.delete(view.id)
      end

      private

      def find(id)
        found(saved_view_repo.by_id(id))
      end
    end
  end
end
