# frozen_string_literal: true

module Admin
  module Operations
    class BuildNotesPage
      RECENT = 8
      TAG = /\A#([a-z0-9-]+)\z/

      include Deps[note_queries: "notes.repos.note_queries"]

      def call(note: nil, folder_id: nil, query: nil)
        listed = note_queries.listed
        tree = grow(listed)
        folder = tree.find(folder_id) if folder_id
        text = Blog::Types::TrimmedText[query]
        filed = filed(folder)
        page = {
          tree:, pinned: listed.select(&:pinned), note:, folder:, filed:, query: text, tag: tag(text),
          hits: hits(tree, text), written: written(listed),
        }

        page.merge(panes(note, folder, filed))
      end

      def tree = grow(note_queries.listed)

      private

      def filed(folder) = folder ? note_queries.filed([folder.id, *folder.all.map(&:id)]) : []

      def grow(listed) = Structs::NoteTree.grow(note_queries.folders, listed)

      def hits(tree, text)
        return Blog::Constants::EMPTY_ARRAY if text.empty?

        name = tag(text)
        return note_queries.tagged(name) if name

        folded = text.downcase
        folder_ids = tree.all.select { it.path.downcase.include?(folded) }.map(&:id)
        note_queries.found(text, folder_ids:)
      end

      def home
        recent = note_queries.recent(RECENT)

        { recent:, backlink_counts: note_queries.backlink_counts(recent.map(&:id)), unwritten: note_queries.unwritten }
      end

      def linked(note) = { backlinks: note_queries.backlinks(note), links_out: note_queries.links_out(note.id) }

      def panes(note, folder, filed)
        return linked(note) if note
        return { backlink_counts: note_queries.backlink_counts(filed.map(&:id)) } if folder

        home
      end

      def tag(text) = TAG.match(text.downcase)&.[](1)

      def written(listed) = listed.to_h { [it.title.downcase, it.id] }
    end
  end
end
