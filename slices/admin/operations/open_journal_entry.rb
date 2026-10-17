# frozen_string_literal: true

module Admin
  module Operations
    class OpenJournalEntry
      KIND = Blog::Types::RecordKind["journal_entry"]

      include Deps[list_record_links: "operations.list_record_links"]

      def call(days, id, records: Blog::Constants::EMPTY_HASH)
        entry = days.rows.flat_map(&:last).find { it.id == id } if id
        return unless entry

        {
          id:, body: entry.body, tags: Blog::Types::TagField[entry.tags], errors: Blog::Constants::EMPTY_HASH,
          records: list_record_links.call(KIND, id, **records),
        }
      end
    end
  end
end
