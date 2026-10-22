# frozen_string_literal: true

module Admin
  module Operations
    class BuildNotesPage
      RECENT = 8

      include Deps[note_queries: "notes.repos.note_queries"]

      def call(note: nil)
        listed = note_queries.listed

        { tree: grow(listed), pinned: listed.select(&:pinned), note:, recent: note ? [] : note_queries.recent(RECENT) }
      end

      def tree = grow(note_queries.listed)

      private

      def grow(listed) = Structs::NoteTree.grow(note_queries.folders, listed)
    end
  end
end
