# frozen_string_literal: true

module Admin
  module UI
    module Components
      class PageHead < Component
        prop :title, Blog::Types::String
        prop :sub, Blog::Types::String.optional
        prop :sub_icon, Blog::Types::String.optional
        prop :kicker, Blog::Types::String.optional

        def view_template(&actions)
          content_for(:title, @title) unless content_for(:title)

          header(class: "page-head") do
            div do
              span(class: "page-head-kicker") { @kicker } if @kicker
              h1(class: "page-head-title") { @title }
              render_sub
            end
            div(class: "page-head-actions", &actions) if actions
          end
        end

        private

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
