# frozen_string_literal: true

module Admin
  module Actions
    module Notes
      class Tag < TagAction
        DONE = "tagged"

        include Deps[tag_note: "notes.operations.tag_note"]

        private

        def list_path = routes.path(:admin_notes)

        def retag(id, tag) = tag_note.call(id, tag)
      end
    end
  end
end
