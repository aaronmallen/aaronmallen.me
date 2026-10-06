# frozen_string_literal: true

module Blog
  module UI
    module Components
      module Posts
        class Date < Component
          prop :time, Blog::Types::Time

          def view_template
            Moment(at: @time, format: :day, class: "dt-published")
          end
        end
      end
    end
  end
end
