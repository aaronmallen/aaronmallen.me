# frozen_string_literal: true

module Blog
  DayPaged = Data.define(:rows, :newer_query, :older_query) do
    def self.query(day) = day ? { to: day.iso8601 } : {}
  end
end
