# frozen_string_literal: true

module Admin
  module Operations
    class ListPaletteSavedViews
      LABELS = Blog::Types::SavedViewScreen.values.to_h { [it, "ui.components.nav.sections.#{it}"] }.freeze

      include Deps["i18n", "routes", saved_view_queries: "saved_views.repos.saved_view_queries"]

      def call = saved_view_queries.all.map { row(it) }

      private

      def row(view)
        screen = UI::Components::SavedViews::SCREENS.fetch(view.screen)

        {
          id: view.id, title: view.name, screen: i18n.t(LABELS.fetch(view.screen)),
          href: UI::Components::SavedViews.href(routes.path(screen), view.filters),
        }
      end
    end
  end
end
