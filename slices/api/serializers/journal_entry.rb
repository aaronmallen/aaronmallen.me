# frozen_string_literal: true

module API
  module Serializers
    class JournalEntry < Serializer
      TIME_FORMAT = "%H:%M"

      attributes :id, :date, :time, :body, :tags

      def date(entry) = day(entry.entry_date)

      def tags(entry) = entry.tags.map(&:name)

      def time(entry) = entry.entry_time.strftime(TIME_FORMAT)
    end
  end
end
