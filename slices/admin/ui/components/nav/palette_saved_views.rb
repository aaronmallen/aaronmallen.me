# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Nav
        class PaletteSavedViews < Component
          ID = "command-palette-group-saved-views"

          def view_template
            PaletteGroup(id: ID, heading: t(".heading"), data: { palette_views: path(:admin_saved_views_palette) }) do
              template(data: { palette_view_row: true }) do
                PaletteRow(id: "", icon: "fa-bookmark", label: "", sub: "", typed: true)
              end
            end
          end
        end
      end
    end
  end
end
