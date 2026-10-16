# frozen_string_literal: true

module Blog
  module UI
    module Components
      class Dotted < Component
        def part(&)
          markup = capture(&)
          return if markup.empty?

          plain DOT if @parted
          @parted = true
          raw(safe(markup))
        end

        def view_template = yield(self)
      end
    end
  end
end
