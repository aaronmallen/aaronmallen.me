# frozen_string_literal: true

module Admin
  module UI
    module Components
      class WebmentionVerdict < Component
        VERDICTS = {
          Blog::Types::WebmentionVerdict["approved"] => ["fa-solid fa-check", ".approve"],
          Blog::Types::WebmentionVerdict["ignored"] => ["fa-regular fa-eye-slash", ".ignore"],
          Blog::Types::WebmentionVerdict["spam"] => ["fa-solid fa-ban", ".spam"],
        }.freeze

        prop :verdict, Blog::Types::WebmentionVerdict
        prop :variant, Blog::Types::Symbol.enum(:pri, :warn, :gh).optional
        prop :icon, Blog::Types::Bool, default: true
        prop :attributes, Blog::Types::Hash, :**

        def view_template
          icon, label_key = VERDICTS.fetch(@verdict)

          Button(type: "submit", variant: @variant, small: true, icon: (icon if @icon), **@attributes) { t(label_key) }
        end
      end
    end
  end
end
