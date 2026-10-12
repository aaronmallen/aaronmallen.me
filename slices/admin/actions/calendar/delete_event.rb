# frozen_string_literal: true

module Admin
  module Actions
    module Calendar
      class DeleteEvent < Action
        include Move
        include Deps[delete_event: "calendar.operations.delete_event"]

        def handle(request, response)
          result = delete_event.call(record_id(request), scope: request.params[:scope])

          written(request, response, result, :event_deleted)
        end
      end
    end
  end
end
