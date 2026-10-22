# frozen_string_literal: true

module Notes
  module Repos
    class NoteQueries < Blog::DB::Repo
      FOUND = %i[id title folder_id body updated_at].freeze

      def by_id(id) = notes.combine(:tags).by_pk(id).one

      def child_folder(parent_id, name)
        note_folders.where(parent_id:).where(Sequel.function(:lower, :name) => name.downcase).order(:id).limit(1).one
      end

      def count = notes.count

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

      def listed = notes.select(:id, :title, :folder_id, :pinned).order(Sequel.function(:lower, :title)).to_a

      def recent(limit) = notes.combine(:tags).order(Sequel.desc(:updated_at), Sequel.desc(:id)).limit(limit).to_a

      def tagged(name) = notes.tagged([name]).select(*FOUND).order(Sequel.desc(:updated_at), Sequel.desc(:id)).to_a
    end
  end
end
