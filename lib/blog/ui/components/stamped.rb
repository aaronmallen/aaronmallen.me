# frozen_string_literal: true

module Blog
  module UI
    module Components
      class Stamped < Component
        MARK = "\u{E000}"

        prop :text, Blog::Types::String
        prop :at, Blog::Types::Time
        prop :format, Blog::Types::Symbol, default: :medium

        def view_template
          before, _, after = @text.partition(MARK)

          plain before
          Moment(at: @at, format: @format)
          plain after
        end
      end
    end
  end
end
