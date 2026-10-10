# frozen_string_literal: true

module Admin
  module UI
    module Components
      class ListItem < Component
        prop :title, Blog::Types::String
        prop :href, Blog::Types::String.optional
        prop :sub, Blog::Types::String.optional
        prop :icon, Blog::Types::String.optional, default: nil
        prop :pick, Blog::Types::Hash.optional, default: nil
        prop :link, Blog::Types::Hash, default: -> { Blog::Constants::EMPTY_HASH }
        prop :data, Blog::Types::Hash, default: -> { Blog::Constants::EMPTY_HASH }
        prop :hover, Blog::Types::Bool, default: false

        def meta(&block)
          @meta = block
          nil
        end

        def view_template(&)
          side = capture(&)

          div(class: "li", data: { key_row: true, **@data }) do
            @pick ? render_picked : render_body
            div(class: ["li-side", ("hov" if @hover)]) { raw(safe(side)) } unless side.empty?
          end
        end

        private

        def main? = @sub || @meta

        def render_body = main? ? render_main : render_head

        def render_head
          return render_title unless @icon

          div(class: "li-head") do
            Icon([@icon, "li-icon"])
            render_title
          end
        end

        def render_main
          div(class: "li-main") do
            render_head
            p(class: "li-sub") { @sub } if @sub
            @meta&.call
          end
        end

        def render_picked
          div(class: "li-start") do
            BulkCheck(**@pick)
            render_body
          end
        end

        def render_title
          if @href
            a(**mix({ class: "li-title", href: @href, data: { key_open: true } }, @link)) { @title }
          else
            span(class: "li-title") { @title }
          end
        end
      end
    end
  end
end
