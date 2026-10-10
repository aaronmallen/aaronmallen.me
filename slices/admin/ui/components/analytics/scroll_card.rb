# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Analytics
        class ScrollCard < Component
          prop :reached, Blog::Types::Array.of(Blog::Types::Hash)
          prop :views, Blog::Types::Integer

          def view_template
            Card(title: t(".title")) do
              next Empty { t(".empty") } if @views.zero?

              Meters(color: :blue, empty: t(".empty"), rows:, total: @views)
            end
          end

          private

          def rows
            @reached.map do |entry|
              views = entry.fetch(:views)
              { count: views, label: t(".depth", depth: entry[:depth]),
                value: t(".share", percent: Blog::Helpers::Figures.share(views, @views)) }
            end
          end
        end
      end
    end
  end
end
