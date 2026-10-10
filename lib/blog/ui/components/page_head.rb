# frozen_string_literal: true

module Blog
  module UI
    module Components
      class PageHead < Component
        prop :title, Blog::Types::String
        prop :sub, Blog::Types::String.optional
        prop :sub_icon, Blog::Types::String.optional
        prop :kicker, Blog::Types::String.optional

        def view_template(&)
          content_for(:title, @title) unless content_for(:title)
          actions = block_given? ? capture(&) : ""

          header(class: "page-head") do
            render_heading
            div(class: "page-head-actions") { raw(safe(actions)) } unless actions.empty?
          end
        end

        private

        def render_heading
          div do
            span(class: "page-head-kicker") { @kicker } if @kicker
            h1(class: "page-head-title") { @title }
            render_sub
          end
        end

        def render_sub
          return unless @sub

          p(class: "page-head-sub") do
            Icon([@sub_icon, "page-head-sub-icon"]) if @sub_icon
            plain @sub
          end
        end
      end
    end
  end
end
