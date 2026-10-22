# frozen_string_literal: true

module Notes
  module Operations
    class RemoveNoteFolder < Blog::Operation
      include Deps[
        note_folder_mutations: "repos.note_folder_mutations",
        note_mutations: "repos.note_mutations",
      ]

      def call(id)
        transaction do
          folder = step found(note_folder_mutations.by_id_for_update(id))
          note_mutations.move_out(id, folder.parent_id)
          note_folder_mutations.move_out(id, folder.parent_id)
          note_folder_mutations.delete(id)
        end
      end
    end
  end
end
