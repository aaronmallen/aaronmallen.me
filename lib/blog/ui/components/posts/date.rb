# frozen_string_literal: true

module Blog
  module UI
    module Components
      module Posts
        class Date < Component
          prop :time, Blog::Types::Time

          def view_template
            time(class: "dt-published", datetime: TimeZone.local(@time).iso8601) do
              l(TimeZone.today(@time), format: :medium)
            end
          end
        end
      end
    end
  end
end
