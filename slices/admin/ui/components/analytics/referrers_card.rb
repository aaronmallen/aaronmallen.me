# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Analytics
        class ReferrersCard < Component
          prop :rows, Blog::Types::Array.of(Blog::Types::Hash)

          def view_template
            MeterCard(color: :blue, empty: t(".empty"), rows:, title: t(".title"))
          end

          private

          def rows = @rows.map { { count: it[:visitors], label: it[:host] || t(".direct") } }
        end
      end
    end
  end
end
