# frozen_string_literal: true

module Blog
  module UI
    module Components
      class Pager < Component
        prop :page, Blog::Types::Interface(:newer_query, :older_query)
        prop :route, Blog::Types::Symbol.optional, default: nil
        prop :href, Blog::Types::Interface(:call).optional, default: nil
        prop :params, Blog::Types::Hash, default: -> { {} }
        prop :newer, Blog::Types::String.optional, default: nil
        prop :older, Blog::Types::String.optional, default: nil

        def view_template
          return unless @page.newer_query || @page.older_query

          nav(class: "pager", aria: { label: t(".label") }) do
            link(@page.newer_query, rel: "prev", label: @newer || t(".newer"), icon: "fa-arrow-left")
            link(@page.older_query, rel: "next", label: @older || t(".older"), icon: "fa-arrow-right")
          end
        end

        private

        def href(query) = @href ? @href.call(query) : path(@route, **@params, **query)

        def link(query, rel:, label:, icon:)
          return unless query

          a(class: ["pager-link", rel], href: href(query), rel:) do
            IconLabel(icon: ["fa-solid", icon]) { label }
          end
        end
      end
    end
  end
end
