# frozen_string_literal: true

module Notes
  module Repos
    class NoteFolderMutations < Blog::DB::Repo
      root :note_folders

      stamped_commands :create, :update
      commands delete: :by_pk

      def by_id_for_update(id) = note_folders.by_pk(id).lock.one

      def move_out(id, parent_id) = note_folders.where(parent_id: id).update(parent_id:, updated_at: Time.now)
    end
  end
end
