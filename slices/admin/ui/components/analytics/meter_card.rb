# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Analytics
        class MeterCard < Component
          prop :color, Blog::Types::Symbol.enum(*Meters::COLORS)
          prop :empty, Blog::Types::String
          prop :rows, Blog::Types::Array.of(Blog::Types::Hash)
          prop :title, Blog::Types::String
          prop :side, Blog::Types::String.optional

          def view_template
            Card(title: @title, note: @side) do
              Meters(color: @color, empty: @empty, rows: @rows)
            end
          end
        end
      end
    end
  end
end
