# frozen_string_literal: true

module Activity
  module Structs
    ReviewJournal = Data.define(:entries, :words, :streak) do
      def self.from(entries)
        days = entries.map(&:occurred_on).uniq.sort

        new(
          entries:,
          words: entries.sum { it.name.split.size },
          streak: days.slice_when { |day, following| following != day + 1 }.map(&:size).max || 0,
        )
      end
    end
  end
end
