# frozen_string_literal: true

module Notes
  module Repos
    class NoteMutations < Blog::DB::Repo
      root :notes

      stamped_commands :create, :update
      commands delete: :by_pk
      tagged_by :note_tags

      def move_out(folder_id, parent_id) = notes.where(folder_id:).update(folder_id: parent_id, updated_at: Time.now)
    end
  end
end
