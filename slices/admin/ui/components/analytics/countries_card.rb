# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Analytics
        class CountriesCard < Component
          prop :rows, Blog::Types::Array.of(Blog::Types::Hash)

          def view_template
            MeterCard(color: :violet, empty: t(".empty"), rows:, title: t(".title"))
          end

          private

          def rows
            @rows.map { { count: it[:visitors], label: it[:country_name] || it[:country_code] || t(".unknown") } }
          end
        end
      end
    end
  end
end
