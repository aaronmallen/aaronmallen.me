# frozen_string_literal: true

module Admin
  module Actions
    module Calendar
      class CreateEvent < Action
        include Move
        include Deps[create_event: "calendar.operations.create_event"]

        def handle(request, response)
          calendar = Blog::Types::IdParam[request.params[:calendar]]

          written(request, response, create_event.call(calendar, request.params.to_h), :event_added)
        end
      end
    end
  end
end
