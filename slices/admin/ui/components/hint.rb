# frozen_string_literal: true

module Admin
  module UI
    module Components
      class Hint < Component
        prop :inline, Blog::Types::Bool, default: false
        prop :attributes, Blog::Types::Hash, :**

        def view_template(&)
          @inline ? span(**tag_attributes, &) : p(**tag_attributes, &)
        end

        private

        def tag_attributes = mix({ class: "hint" }, @attributes)
      end
    end
  end
end
