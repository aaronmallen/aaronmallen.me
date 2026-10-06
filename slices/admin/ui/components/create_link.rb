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
          Button(
            href: @href, variant: :pri, icon: "fa-solid fa-plus", aria: { keyshortcuts: KEY },
            data: { dialog_open: @dialog, key: KEY, key_label: @label },
          ) { @label }
        end
      end
    end
  end
end
