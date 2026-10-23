# frozen_string_literal: true

module Admin
  module Actions
    module Notes
      class Menu < Action
        RECORD = Blog::Types::RecordKind["note"]

        include Deps[
          build_notes_page: "operations.build_notes_page",
          note_queries: "notes.repos.note_queries",
          tag_queries: "tags.repos.tag_queries",
        ]

        def handle(request, response)
          note = note_queries.by_id(record_id(request)) || halt(:not_found)
          tree = build_notes_page.tree

          response.render(view, note:, tree:, tags: tag_queries.choices_for(RECORD, note.id),
                                return_to: back_here(request))
        end
      end
    end
  end
end
