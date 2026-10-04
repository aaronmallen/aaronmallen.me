# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Nav
        class PaletteRow < Component
          prop :id, Blog::Types::String
          prop :icon, Blog::Types::String
          prop :text, Blog::Types::String, default: -> { "" }
          prop :label, Blog::Types::String.optional, default: nil
          prop :match, Blog::Types::String.optional, default: nil
          prop :sub, Blog::Types::String.optional, default: nil
          prop :warn, Blog::Types::Bool, default: false
          prop :href, Blog::Types::String.optional, default: nil
          prop :dialog, Blog::Types::String.optional, default: nil
          prop :found, Blog::Types::Bool, default: false

          def view_template
            div(
              id: @id, class: "pal-r", role: "option", aria: { selected: "false" },
              data: {
                palette_option: true, palette_text: @text, palette_href: @href,
                palette_dialog: @dialog, palette_found: (true if @found),
              },
            ) do
              i(class: ["fa-solid", @icon, "pal-r-icon"], aria: { hidden: "true" })
              @match ? text_with_match : span(class: "pal-r-label") { @label }
              span(class: ["pal-r-sub", ("warn" if @warn)]) { @sub } if @sub
            end
          end

          private

          def text_with_match
            span(class: "pal-r-text") do
              span(class: "pal-r-label") { @label }
              span(class: "pal-r-match") { @match }
            end
          end
        end
      end
    end
  end
end
