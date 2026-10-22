# frozen_string_literal: true

module Admin
  module Actions
    module Notes
      class Pin < Action
        PINNED = "notes_page.toasts.pinned"
        UNPINNED = "notes_page.toasts.unpinned"

        include Place
        include Deps[pin_note: "notes.operations.pin_note"]

        def handle(request, response)
          pinned = Blog::Types::Checkbox[request.params[:pinned]]

          settle(response, pin_note.call(record_id(request), pinned:), pinned ? PINNED : UNPINNED, back(request))
        end
      end
    end
  end
end
