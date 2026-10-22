# frozen_string_literal: true

module API
  module Endpoints
    class ReadNote < NoteEndpoint
      SCHEMA = Helpers::Schema.by_id
      KIND = Blog::Types::RecordKind["note"]
      LINKED = Helpers::Schema.object({ id: Helpers::Schema::INTEGER, title: Helpers::Schema::STRING })
      LINK_OUT = Helpers::Schema.object(
        {
          id: Helpers::Schema.nullable({ type: "integer", description: "null when no note has the title yet" }),
          title: Helpers::Schema::STRING,
        },
      )
      REPLY = Helpers::Schema.widen(
        Serializers::Note::SCHEMA,
        backlinks: Helpers::Schema.list(LINKED).merge(description: "the other notes that link to this one"),
        links_out: Helpers::Schema.list(LINK_OUT).merge(description: "the titles its [[links]] name"),
        record_links: Serializers::Link::GROUPS,
      ).freeze

      include Deps[record_link_queries: "links.repos.record_link_queries"]

      def handle(id:)
        found = note_queries.by_id(id)
        return missing("note", id) if found.nil?

        Success(
          note(found).merge(backlinks: backlinks(found), links_out: links_out(found),
                            record_links: links_for(found.id)),
        )
      end

      private

      def backlinks(found) = note_queries.backlinks(found).map { titled(it[:id], it[:title], it[:written_by_agent]) }

      def links_out(found)
        links = note_queries.links_out(found.id)
        written = note_queries.written_by_agent(links.filter_map { it[:id] })

        links.map { titled(it[:id], it[:title], found.written_by_agent || written.include?(it[:id])) }
      end

      def titled(id, title, agent) = { id:, title: agent ? Helpers::Untrusted.call(title) : title }
    end
  end
end
