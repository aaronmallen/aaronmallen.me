# frozen_string_literal: true

module Admin
  module Actions
    module Notes
      class DescribeFolder < Action
        DESCRIBED = "notes_page.toasts.described"

        include Place
        include Deps[describe_note_folder: "notes.operations.describe_note_folder"]

        def handle(request, response)
          described = describe_note_folder.call(record_id(request), description: request.params[:description].to_s)

          settle(response, described, DESCRIBED, back(request)) { refused(request, response, it) }
        end
      end
    end
  end
end
