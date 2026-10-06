# frozen_string_literal: true

module Admin
  module UI
    module Components
      class DateRange < Component
        prop :from, Blog::Types::Date
        prop :to, Blog::Types::Date
        prop :id_prefix, Blog::Types::String

        def view_template
          Field(label: t(".from"), id: "#{@id_prefix}-from") do |control|
            Input(**control, type: "date", name: "from", value: @from.iso8601, max: @to.iso8601)
          end
          Field(label: t(".to"), id: "#{@id_prefix}-to") do |control|
            Input(**control, type: "date", name: "to", value: @to.iso8601, min: @from.iso8601)
          end
        end
      end
    end
  end
end
