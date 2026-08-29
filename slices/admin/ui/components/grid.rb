# frozen_string_literal: true

module Admin
  module UI
    module Components
      class Grid < Component
        CLASSES = { 2 => "g-2", 3 => "g-3", 4 => "g-4" }.freeze

        prop :columns, Blog::Types::Integer.enum(*CLASSES.keys)

        def view_template(&)
          div(class: CLASSES.fetch(@columns), &)
        end
      end
    end
  end
end
