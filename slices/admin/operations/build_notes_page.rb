# frozen_string_literal: true

module Admin
  module Operations
    class BuildNotesPage
      include Blog::Constants

      FOLDER = Blog::Types::RecordKind["note_folder"]
      NOTE = Blog::Types::RecordKind["note"]
      RECENT = 8

      include Deps[
        list_record_links: "operations.list_record_links",
        note_queries: "notes.repos.note_queries",
        record_link_queries: "links.repos.record_link_queries",
        search_notes: "notes.operations.search_notes",
      ]

      def call(note: nil, folder_id: nil, query: nil, records: EMPTY_HASH)
        listed = note_queries.listed
        tree = grow(listed)
        folder = tree.find(folder_id) if folder_id
        filed = filed(folder)
        page = {
          tree:, pinned: listed.select(&:pinned), note:, folder:, filed:, written: written(listed),
          **searched(query),
        }

        page.merge(panes(tree, note, folder, filed, records))
      end

      def tree = grow(note_queries.listed)

      private

      def filed(folder) = folder ? note_queries.filed([folder.id, *folder.all.map(&:id)]) : []

      def folder_links(folders)
        folders.flat_map do |folder|
          record_link_queries.for_record(FOLDER, folder.id).values.flatten.map { [folder, it] }
        end
      end

      def grow(listed) = Structs::NoteTree.grow(note_queries.folders, listed)

      def home
        recent = note_queries.recent(RECENT)

        { recent:, backlink_counts: note_queries.backlink_counts(recent.map(&:id)), unwritten: note_queries.unwritten }
      end

      def linked(note) = { backlinks: note_queries.backlinks(note), links_out: note_queries.links_out(note.id) }

      def links(kind, id, folders, records)
        { records: list_record_links.call(kind, id, **records), from_folders: folder_links(folders) }
      end

      def panes(tree, note, folder, filed, records)
        return { **linked(note), **links(NOTE, note.id, tree.trail(note.folder_id), records) } if note
        return home unless folder

        counts = note_queries.backlink_counts(filed.map(&:id))
        { backlink_counts: counts, **links(FOLDER, folder.id, tree.trail(folder.id)[...-1], records) }
      end

      def searched(query)
        text = Blog::Types::TrimmedText[query]

        { query: text, tag: ::Notes::Operations::SearchNotes.tag(text), hits: search_notes.call(text) }
      end

      def written(listed) = listed.to_h { [it.title.downcase, it.id] }
    end
  end
end
