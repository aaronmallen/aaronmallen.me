# frozen_string_literal: true

module Notes
  class Slice < Hanami::Slice
    export %w[
      operations.create_note operations.create_note_folder operations.delete_note operations.describe_note_folder
      operations.duplicate_note operations.edit_note operations.move_note operations.move_note_folder
      operations.pin_note operations.remove_note_folder operations.rename_note operations.rename_note_folder
      operations.tag_note operations.untag_note repos.note_queries
    ]
  end
end
