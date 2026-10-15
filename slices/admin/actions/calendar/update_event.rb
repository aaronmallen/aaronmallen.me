# frozen_string_literal: true

module Admin
  module Actions
    module Calendar
      class UpdateEvent < EventWrite
        include Deps[edit_event: "calendar.operations.edit_event"]

        def handle(request, response)
          id = record_id(request)
          result = edit_event.call(id, request.params.to_h, scope: request.params[:scope])

          written(request, response, result, :event_saved) { refuse(request, response, it, id:) }
        end
      end
    end
  end
end
