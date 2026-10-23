# frozen_string_literal: true

module Notes
  module Repos
    class NoteQueries < Blog::DB::Repo
      FOUND = %i[id title folder_id body pinned updated_at written_by_agent].freeze

      def backlink_counts(ids) = note_links.backlink_counts(ids).to_h { [it[:id], it[:count]] }

      def backlinks(note)
        linking = notes.where(id: note_links.linking(note.title).select(:note_id).dataset).exclude(id: note.id)

        linking.select(:id, :title, :body, :written_by_agent).order(Sequel.function(:lower, :title)).to_a
      end

      def by_id(id) = notes.combine(:tags).by_pk(id).one

      def child_folder(parent_id, name)
        note_folders.where(parent_id:).where(Sequel.function(:lower, :name) => name.downcase).order(:id).limit(1).one
      end

      def count = notes.count

      def filed(folder_ids)
        notes.combine(:tags).where(folder_id: folder_ids).order(Sequel.desc(:updated_at), Sequel.desc(:id)).to_a
      end

      def folder_by_id(id) = note_folders.by_pk(id).one

      def folders = note_folders.order(Sequel.function(:lower, :name), :id).to_a

      def found(text, folder_ids:)
        tagged = note_tags.join(:tags, id: :tag_id).where(Sequel.ilike(Sequel[:tags][:name], notes.like_pattern(text)))
        ids = notes.where(folder_id: folder_ids).pluck(:id) | tagged.pluck(:note_id)

        notes.containing(text, :title, :body, ids:).titles_first(text).select(*FOUND).to_a
      end

      def free_title(base)
        taken = notes.titled_from(base).pluck(:title).to_set(&:downcase)

        (1..).lazy.map { it == 1 ? base : "#{base} #{it}" }.find { !taken.include?(it.downcase) }
      end

      def links_out(id) = note_links.out(id).to_a

      def listed
        listing = notes.select(:id, :title, :folder_id, :pinned, :updated_at, :written_by_agent)
        listing.order(Sequel.function(:lower, :title)).to_a
      end

      def page_by_tag(tag_ids, page)
        found = notes.carrying(:note_tags, tag_ids).order(Sequel.desc(:updated_at), Sequel.desc(:id))

        page.fill(found.select(:id, :title, :updated_at).paged(page).to_a)
      end

      def recent(limit) = notes.combine(:tags).order(Sequel.desc(:updated_at), Sequel.desc(:id)).limit(limit).to_a

      def relinks(id, title)
        note = notes.by_pk(id).one
        return 0 if note.nil? || note.title == Blog::Types::TrimmedText[title]

        backlink_counts([id]).fetch(id, 0)
      end

      def tagged(name) = notes.tagged([name]).select(*FOUND).order(Sequel.desc(:updated_at), Sequel.desc(:id)).to_a

      def unwritten
        rows = note_links.unwritten.to_a

        rows.chunk_while { |link, other| link[:title].casecmp?(other[:title]) }.map do |linked|
          { title: linked.first[:title], sources: linked.map { it[:source] }, folder_id: linked.first[:folder_id] }
        end
      end

      def written_by_agent(ids) = notes.where(id: ids, written_by_agent: true).pluck(:id)
    end
  end
end
