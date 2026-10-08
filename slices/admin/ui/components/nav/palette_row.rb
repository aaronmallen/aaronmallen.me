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
          prop :typed, Blog::Types::Bool, default: false
          prop :all, Blog::Types::String.optional, default: nil
          prop :post, Blog::Types::Bool, default: false
          prop :needs, Blog::Types::String.optional, default: nil
          prop :jump, Blog::Types::String.optional, default: nil
          prop :key, Blog::Types::String.optional, default: nil
          prop :click, Blog::Types::String.optional, default: nil
          prop :fill, Blog::Types::String.optional, default: nil
          prop :query, Blog::Types::Bool, default: false

          def view_template
            div(
              id: @id, class: "pal-r", role: "option", aria: { selected: "false" },
              data: {
                palette_option: true, palette_text: @text, palette_href: @href, palette_dialog: @dialog,
                palette_found: (true if @found), palette_typed: (true if @typed), palette_post: (true if @post),
                palette_needs: @needs, palette_all: @all, palette_click: @click, palette_fill: @fill,
                palette_label: (@label if @query), **key_data,
              },
            ) do
              Icon(["fa-solid", @icon, "pal-r-icon"])
              @match ? text_with_match : span(class: "pal-r-label") { @label }
              trailing
            end
          end

          private

          def key_data
            return { key: "#{JUMP} #{@jump}", key_label: t(".jump", section: @label) } if @jump
            return { key: @key, key_label: @label } if @key

            Blog::Constants::EMPTY_HASH
          end

          def text_with_match
            span(class: "pal-r-text") do
              span(class: "pal-r-label") { @label }
              span(class: "pal-r-match") { @match }
            end
          end

          def trailing
            span(class: ["pal-r-sub", ("warn" if @warn)]) { @sub } if @sub
            span(class: "kbd pal-r-key", aria: { hidden: "true" }) { @key } if @key&.length == 1
          end
        end
      end
    end
  end
end
