# frozen_string_literal: true

module Admin
  module Actions
    module Calendar
      class CreateEvent < EventWrite
        include Deps[create_event: "calendar.operations.create_event"]

        def handle(request, response)
          calendar = Blog::Types::IdParam[request.params[:calendar]]
          result = create_event.call(calendar, request.params.to_h)

          written(request, response, result, :event_added) { refuse(request, response, it) }
        end
      end
    end
  end
end
