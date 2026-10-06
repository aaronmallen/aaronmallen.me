# frozen_string_literal: true

module Blog
  module UI
    module Components
      class Icon < Component
        TOKEN = Blog::Types::String | Blog::Types::Symbol
        NAME = TOKEN | Blog::Types::Array.of(TOKEN)

        prop :name, NAME, :positional
        prop :label, Blog::Types::String.optional, default: nil

        def view_template
          i(class: @name, **labelling)
        end

        private

        def labelling = @label ? { role: "img", aria: { label: @label } } : { aria: { hidden: "true" } }
      end
    end
  end
end
