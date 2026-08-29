# frozen_string_literal: true

module Public
  module UI
    module Components
      class WorkRow < Component
        WRITING = /\S/

        prop :entry, Blog::Types::Instance(ROM::Struct)

        def view_template
          div(class: "row") do
            div(class: "yr") { years }
            div do
              h3 { @entry.role }
              div(class: "at") { @entry.org }
              p { @entry.blurb } if written?(@entry.blurb)
            end
          end
        end

        private

        def written?(value) = value.to_s.match?(WRITING)

        def years = t(".years", from: @entry.from_year, to: @entry.current? ? t(".current") : @entry.to_year)
      end
    end
  end
end
