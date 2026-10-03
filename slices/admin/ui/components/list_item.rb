# frozen_string_literal: true

module Admin
  module UI
    module Components
      class ListItem < Component
        prop :title, Blog::Types::String
        prop :href, Blog::Types::String.optional
        prop :sub, Blog::Types::String.optional

        def view_template(&side)
          div(class: "li", data: { key_row: true }) do
            @sub ? render_main : render_title
            div(class: "li-side", &side) if side
          end
        end

        private

        def render_main
          div(class: "li-main") do
            render_title
            p(class: "li-sub") { @sub }
          end
        end

        def render_title
          if @href
            a(class: "li-title", href: @href, data: { key_open: true }) { @title }
          else
            span(class: "li-title") { @title }
          end
        end
      end
    end
  end
end
