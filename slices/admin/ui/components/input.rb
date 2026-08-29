# frozen_string_literal: true

module Admin
  module UI
    module Components
      class Input < Component
        TYPES = %w[date datetime-local email number password search text time url].freeze

        prop :type, Blog::Types::String.enum(*TYPES), default: "text"
        prop :attributes, Blog::Types::Hash, :**

        def view_template
          input(**mix({ class: "inp", type: @type }, @attributes))
        end
      end
    end
  end
end
