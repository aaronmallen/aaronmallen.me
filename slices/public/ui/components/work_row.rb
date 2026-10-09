# frozen_string_literal: true

module Public
  module UI
    module Components
      class WorkRow < Component
        prop :entry, Blog::Types::Instance(ROM::Struct)

        def view_template
          div(class: "cr") do
            span(class: "yr") { years }
            h3 { @entry.role }
            span(class: "at") { @entry.org }
            p { @entry.blurb } if written?(@entry.blurb)
          end
        end

        private

        def years = t(".years", from: @entry.from_year, to: @entry.current? ? t(".current") : @entry.to_year)
      end
    end
  end
end
