# frozen_string_literal: true

module Admin
  module Actions
    module Notes
      class CreateFolder < Action
        CREATED = "notes_page.toasts.folder_created"

        include Place
        include Deps["notes.operations.create_note_folder_path"]

        def handle(request, response)
          params = request.params

          case create_note_folder_path.call("#{params[:prefix]}/#{params[:path]}")
            in Success(nil) then toast_back(response, "#{TOASTS}.refused.invalid", back(request))
            in Success(_) then toast_back(response, CREATED, back(request))
            in Failure[:invalid, errors] then refused(request, response, errors)
          end
        end
      end
    end
  end
end
