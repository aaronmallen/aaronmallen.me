# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Nav
        class PaletteRecords < Component
          ID = "command-palette-group-records"
          KINDS = {
            Blog::Types::SearchKind["task"] => "fa-list-check",
            Blog::Types::SearchKind["post"] => "fa-file-lines",
            Blog::Types::SearchKind["social"] => "fa-paper-plane",
            Blog::Types::SearchKind["journal"] => "fa-feather",
            Blog::Types::SearchKind["commit"] => "fa-code-commit",
            Blog::Types::SearchKind["project"] => "fa-cube",
            Blog::Types::SearchKind["work"] => "fa-briefcase",
            Blog::Types::SearchKind["person"] => "fa-address-book",
            Blog::Types::SearchKind["message"] => "fa-envelope",
            Blog::Types::SearchKind["webmention"] => "fa-at",
            Blog::Types::SearchKind["decision"] => "fa-scale-balanced",
            Blog::Types::SearchKind["pull_request"] => "fa-code-pull-request",
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
