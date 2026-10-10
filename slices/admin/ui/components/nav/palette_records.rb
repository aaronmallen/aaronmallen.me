# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Nav
        class PaletteRecords < Component
          ID = "command-palette-group-records"
          KINDS = {
            **Blog::Helpers::RecordKinds::ALL.values.to_h { [it.search_kind, it.icon] },
            Blog::Types::SearchKind["person"] => "fa-address-book",
            Blog::Types::SearchKind["message"] => "fa-envelope",
            Blog::Types::SearchKind["webmention"] => "fa-at",
          }.freeze
          KIND_KEYS = KINDS.keys.to_h { [it, ".kinds.#{it}"] }.freeze

          def view_template
            PaletteGroup(id: ID, heading: t(".heading"), data: { palette_records: true }) do
              KINDS.each do |kind, icon|
                template(data: { palette_found_row: kind }) do
                  PaletteRow(id: "", icon:, label: "", match: "", sub: t(KIND_KEYS.fetch(kind)), found: true)
                end
              end
            end
          end
        end
      end
    end
  end
end
