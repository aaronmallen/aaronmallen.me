# frozen_string_literal: true

module API
  module Serializers
    class JournalEntry < Serializer
      TIME_FORMAT = "%H:%M"

      SCHEMA = Schema.object(
        {
          id: Schema::INTEGER,
          date: Schema::DAY,
          time: { type: "string", description: "the time of day, as HH:MM" },
          body: { type: "string", description: "the entry, in Markdown" },
          tags: Schema::TAGS,
        },
      ).freeze

      attributes :id, :date, :time, :body, :tags

      def date(entry) = day(entry.entry_date)

      def tags(entry) = entry.tags.map(&:name)

      def time(entry) = entry.entry_time.strftime(TIME_FORMAT)
    end
  end
end
