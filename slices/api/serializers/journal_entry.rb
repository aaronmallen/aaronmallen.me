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
          created_at: Schema::STAMP,
          updated_at: Schema::STAMP,
        },
      ).freeze

      attributes :id, :date, :time, :body, :tags, :created_at, :updated_at

      def created_at(entry) = stamp(entry.created_at)

      def date(entry) = day(entry.entry_date)

      def tags(entry) = entry.tags.map(&:name)

      def time(entry) = entry.entry_time.strftime(TIME_FORMAT)

      def updated_at(entry) = stamp(entry.updated_at)
    end
  end
end
