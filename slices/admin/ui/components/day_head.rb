# frozen_string_literal: true

module Admin
  module UI
    module Components
      class DayHead < Component
        SEPARATOR = " · "

        prop :date, Blog::Types::Date
        prop :today, Blog::Types::Date
        prop :count, Blog::Types::Integer.optional, default: nil
        prop :format, Blog::Types::Symbol.enum(:full, :long), default: :full
        prop :sunk, Blog::Types::Bool, default: false

        def view_template
          h2(class: ["day-head", ("sunk" if @sunk)]) do
            time(class: "day-date", datetime: @date.iso8601) { l(@date, format: @format) }
            span(class: "day-rule", aria: { hidden: "true" })
            span(class: "day-note") { note } unless note.empty?
          end
        end

        private

        def ago
          case days_ago
          when 0 then t(".today")
          when 1 then t(".yesterday")
          else t(".days_ago", count: days_ago) if days_ago.positive?
          end
        end

        def days_ago = (@today - @date).to_i

        def note = [ago, @count&.to_s].compact.join(SEPARATOR)
      end
    end
  end
end
