# frozen_string_literal: true

module Admin
  module UI
    module Components
      class CopyButton < Component
        prop :value, Blog::Types::String
        prop :copied, Blog::Types::String
        prop :bare, Blog::Types::Bool, default: false
        prop :attributes, Blog::Types::Hash, :**

        def view_template(&)
          data = { data: { record_key: @value, record_key_copied: @copied } }
          return button(**mix({ type: "button" }, data, @attributes), &) if @bare

          Button(**mix(data, @attributes), &)
        end
      end
    end
  end
end
