# frozen_string_literal: true

module API
  module Serializers
    class JournalEntry < Serializer
      SCHEMA = Helpers::Schema.object(
        {
          id: Helpers::Schema::INTEGER,
          date: Helpers::Schema::DAY,
          time: { type: "string", description: "the time of day, as HH:MM" },
          body: { type: "string", description: "the entry, in Markdown" },
          tags: Helpers::Schema::TAGS,
          created_at: Helpers::Schema::STAMP,
          updated_at: Helpers::Schema::STAMP,
        },
      ).freeze

      schema_attributes
      stamps :created_at, :updated_at
      tag_names

      def date(entry) = day(entry.entry_date)

      def time(entry) = clock(entry.entry_time)
    end
  end
end
