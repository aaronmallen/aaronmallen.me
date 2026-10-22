# frozen_string_literal: true

module Admin
  module Operations
    class BuildNotesPage
      RECENT = 8
      TAG = /\A#([a-z0-9-]+)\z/

      include Deps[note_queries: "notes.repos.note_queries"]

      def call(note: nil, query: nil)
        listed = note_queries.listed
        tree = grow(listed)
        text = Blog::Types::TrimmedText[query]

        {
          tree:, pinned: listed.select(&:pinned), note:, recent: note ? [] : note_queries.recent(RECENT),
          query: text, tag: tag(text), hits: hits(tree, text),
        }
      end

      def tree = grow(note_queries.listed)

      private

      def grow(listed) = Structs::NoteTree.grow(note_queries.folders, listed)

      def hits(tree, text)
        return Blog::Constants::EMPTY_ARRAY if text.empty?

        name = tag(text)
        return note_queries.tagged(name) if name

        folded = text.downcase
        folder_ids = tree.all.select { it.path.downcase.include?(folded) }.map(&:id)
        note_queries.found(text, folder_ids:)
      end

      def tag(text) = TAG.match(text.downcase)&.[](1)
    end
  end
end
