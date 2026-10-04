# frozen_string_literal: true

module Admin
  module UI
    module Components
      class CreateLink < Component
        KEY = "c"

        prop :href, Blog::Types::String
        prop :label, Blog::Types::String
        prop :dialog, Blog::Types::String.optional, default: nil

        def view_template
          a(
            class: "btn pri", href: @href, aria: { keyshortcuts: KEY },
            data: { dialog_open: @dialog, key: KEY, key_label: @label },
          ) do
            i(class: "fa-solid fa-plus", aria: { hidden: "true" })
            span { @label }
          end
        end
      end
    end
  end
end
