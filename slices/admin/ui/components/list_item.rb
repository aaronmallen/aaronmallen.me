# frozen_string_literal: true

module Admin
  module UI
    module Components
      class ListItem < Component
        prop :title, Blog::Types::String
        prop :href, Blog::Types::String.optional
        prop :sub, Blog::Types::String.optional
        prop :pick, Blog::Types::Hash.optional, default: nil
        prop :beside, Blog::Types::Instance(Phlex::SGML).optional, default: nil
        prop :data, Blog::Types::Hash, default: -> { Blog::Constants::EMPTY_HASH }

        def view_template(&side)
          div(class: "li", data: { key_row: true, **@data }) do
            @pick ? render_picked : render_body
            div(class: "li-side", &side) if side
          end
        end

        private

        def render_body = @sub ? render_main : render_head

        def render_head
          return render_title unless @beside

          div(class: "li-head") do
            render_title
            render @beside
          end
        end

        def render_main
          div(class: "li-main") do
            render_head
            p(class: "li-sub") { @sub }
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
            a(class: "li-title", href: @href, data: { key_open: true }) { @title }
          else
            span(class: "li-title") { @title }
          end
        end
      end
    end
  end
end
