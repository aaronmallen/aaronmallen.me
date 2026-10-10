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
          prop :linked, Blog::Types::Hash, default: Blog::Constants::EMPTY_HASH

          def self.anchor(date) = "day-#{date.iso8601}"

          def view_template
            section(class: "journal-day", id: self.class.anchor(@date)) do
              DayHead(date: @date, today: @today)
              div do
                @entries.each do |entry|
                  Entry(entry:, date: @date, editing: editing_for(entry), linked: @linked.fetch(entry.id, 0))
                end
              end
            end
          end

          private

          def editing_for(entry) = (@editing if @editing && @editing[:id] == entry.id)
        end
      end
    end
  end
end
