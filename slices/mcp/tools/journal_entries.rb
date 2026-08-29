# frozen_string_literal: true

module MCP
  module Tools
    module JournalEntries
      BLANK = "blank"
      FORMAT = Blog::Contract::FORMAT
      TAG_SEPARATOR = ","
      TIME_FORMAT = "%H:%M"

      COMPLAINTS = {
        [:body, BLANK] => "body needs a character that is not a space",
        [:body, Blog::Contract::CONTROL] => "body holds a control character",
        [:entry_date, FORMAT] => "entry_date needs a day, such as 2026-01-01",
        [:entry_date, "future"] => "entry_date falls after today; pick today or an earlier day",
        [:tags, FORMAT] => "tags take lowercase letters, numbers and single dashes in each tag",
      }.freeze

      TAGS = {
        type: "array",
        items: { type: "string" },
        description: "tag names, such as ruby or health, in lowercase letters, numbers and single dashes",
      }.freeze

      module_function

      def complaint(errors)
        errors.flat_map { |field, tokens| tokens.map { COMPLAINTS.fetch([field, it]) { "#{field} #{it}" } } }
              .join("; ")
      end

      def fields(entry)
        {
          id: entry.id,
          date: entry.entry_date.iso8601,
          time: entry.entry_time.strftime(TIME_FORMAT),
          body: entry.body,
          tags: entry.tags.map(&:name),
        }
      end

      def tag_list(tags) = Array(tags).join(TAG_SEPARATOR)
    end
  end
end
