# frozen_string_literal: true

module Admin
  module Actions
    module Calendar
      class UpdateEvent < Action
        include Move
        include Deps[edit_event: "calendar.operations.edit_event"]

        def handle(request, response)
          result = edit_event.call(record_id(request), request.params.to_h, scope: request.params[:scope])

          written(request, response, result, :event_saved)
        end
      end
    end
  end
end
