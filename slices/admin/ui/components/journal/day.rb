# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Journal
        class Day < Component
          prop :date, Blog::Types::Date
          prop :entries, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :today, Blog::Types::Date
          prop :editing, Blog::Types::Hash.optional, default: nil

          def self.anchor(date) = "day-#{date.iso8601}"

          def view_template
            section(class: "journal-day", id: self.class.anchor(@date)) do
              h2(class: "journal-day-head") do
                time(class: "journal-day-date", datetime: @date.iso8601) { l(@date, format: :full) }
                span(class: "journal-day-rule", aria: { hidden: "true" })
                span(class: "journal-day-ago") { ago } unless days_ago.negative?
              end
              @entries.each { Entry(entry: it, date: @date, editing: editing_for(it)) }
            end
          end

          private

          def ago
            case days_ago
            when 0 then t(".today")
            when 1 then t(".yesterday")
            else t(".days_ago", count: days_ago)
            end
          end

          def days_ago = (@today - @date).to_i

          def editing_for(entry) = (@editing if @editing && @editing[:id] == entry.id)
        end
      end
    end
  end
end
