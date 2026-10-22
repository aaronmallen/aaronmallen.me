# frozen_string_literal: true

module Admin
  module Actions
    module Notes
      class Create < Action
        CREATED = "notes_page.toasts.created"

        include Place
        include Deps[create_note: "notes.operations.create_note"]

        def handle(request, response)
          params = request.params

          case create_note.call(title: params[:title], folder_id: Blog::Types::IdParam[params[:folder_id]])
            in Success(note) then toast_back(response, CREATED, routes.path(:admin_note, id: note.id, edit: 1))
            in Failure[:invalid, errors] then refused(request, response, errors)
          end
        end
      end
    end
  end
end
