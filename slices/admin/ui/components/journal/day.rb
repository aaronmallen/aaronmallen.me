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
              DayHead(date: @date, today: @today)
              @entries.each { Entry(entry: it, date: @date, editing: editing_for(it)) }
            end
          end

          private

          def editing_for(entry) = (@editing if @editing && @editing[:id] == entry.id)
        end
      end
    end
  end
end
