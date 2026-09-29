# frozen_string_literal: true

module Blog
  module UI
    module Components
      class Pager < Component
        prop :page, Blog::Types::Instance(Blog::Paged)
        prop :route, Blog::Types::Symbol
        prop :params, Blog::Types::Hash, default: -> { {} }

        def view_template
          return unless @page.previous_number || @page.next_number

          nav(class: "pager", aria: { label: t(".label") }) do
            link(@page.previous_number, rel: "prev", label_key: ".newer", icon: "fa-arrow-left")
            link(@page.next_number, rel: "next", label_key: ".older", icon: "fa-arrow-right")
          end
        end

        private

        def link(number, rel:, label_key:, icon:)
          return unless number

          a(class: ["pager-link", rel], href: path(@route, **@params, **Blog::Page.query(number)), rel:) do
            i(class: ["fa-solid", icon], aria: { hidden: "true" })
            span { t(label_key) }
          end
        end
      end
    end
  end
end
