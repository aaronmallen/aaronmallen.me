# frozen_string_literal: true

module Notes
  module Repos
    class NoteQueries < Blog::DB::Repo
      def by_id(id) = notes.combine(:tags).by_pk(id).one

      def child_folder(parent_id, name)
        note_folders.where(parent_id:).where(Sequel.function(:lower, :name) => name.downcase).order(:id).limit(1).one
      end

      def count = notes.count

      def folder_by_id(id) = note_folders.by_pk(id).one

      def folders = note_folders.order(Sequel.function(:lower, :name), :id).to_a

      def free_title(base)
        taken = notes.titled_from(base).pluck(:title).to_set(&:downcase)

        (1..).lazy.map { it == 1 ? base : "#{base} #{it}" }.find { !taken.include?(it.downcase) }
      end

      def listed = notes.select(:id, :title, :folder_id, :pinned).order(Sequel.function(:lower, :title)).to_a

      def recent(limit) = notes.combine(:tags).order(Sequel.desc(:updated_at), Sequel.desc(:id)).limit(limit).to_a
    end
  end
end
