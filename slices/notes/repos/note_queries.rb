# frozen_string_literal: true

module Notes
  module Repos
    class NoteQueries < Blog::DB::Repo
      def by_id(id) = notes.combine(:tags).by_pk(id).one

      def folder_by_id(id) = note_folders.by_pk(id).one

      def free_title(base)
        taken = notes.titled_from(base).pluck(:title).to_set(&:downcase)

        (1..).lazy.map { it == 1 ? base : "#{base} #{it}" }.find { !taken.include?(it.downcase) }
      end
    end
  end
end
