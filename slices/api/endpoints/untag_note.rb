# frozen_string_literal: true

module API
  module Endpoints
    class UntagNote < NoteEndpoint
      SCHEMA = {
        additionalProperties: false,
        properties: { id: Notes::ID, tag: { type: "string", description: "the tag to take off" } },
        required: %w[id tag],
      }.freeze

      include Deps[untag_note: "notes.operations.untag_note"]

      def handle(id:, tag:)
        found = note_queries.by_id(id)
        return missing("note", id) if found.nil?

        name = Blog::Types::TagList[tag].first
        return not_found("note #{id} has no tag #{tag}") unless found.tags.map(&:name).include?(name)

        settled(untag_note.call(id, name), id) { note(it) }
      end
    end
  end
end
