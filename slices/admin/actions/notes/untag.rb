# frozen_string_literal: true

module Admin
  module Actions
    module Notes
      class Untag < TagAction
        DONE = "untagged"

        include Deps[untag_note: "notes.operations.untag_note"]

        private

        def list_path = routes.path(:admin_notes)

        def retag(id, tag) = untag_note.call(id, tag)
      end
    end
  end
end
