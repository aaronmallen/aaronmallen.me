# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Nav
        class PaletteRow < Component
          JUMP = "g"

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
          prop :all, Blog::Types::String.optional, default: nil
          prop :post, Blog::Types::Bool, default: false
          prop :needs, Blog::Types::String.optional, default: nil
          prop :jump, Blog::Types::String.optional, default: nil

          def view_template
            div(
              id: @id, class: "pal-r", role: "option", aria: { selected: "false" },
              data: {
                palette_option: true, palette_text: @text, palette_href: @href,
                palette_dialog: @dialog, palette_found: (true if @found), palette_post: (true if @post),
                palette_needs: @needs, palette_all: @all, **jump_key,
              },
            ) do
              i(class: ["fa-solid", @icon, "pal-r-icon"], aria: { hidden: "true" })
              @match ? text_with_match : span(class: "pal-r-label") { @label }
              span(class: ["pal-r-sub", ("warn" if @warn)]) { @sub } if @sub
            end
          end

          private

          def jump_key
            return Blog::Constants::EMPTY_HASH unless @jump

            { key: "#{JUMP} #{@jump}", key_label: t(".jump", section: @label) }
          end

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
