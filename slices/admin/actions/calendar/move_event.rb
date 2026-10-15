# frozen_string_literal: true

module Admin
  module Actions
    module Calendar
      class MoveEvent < Action
        include Redirect
        include Deps[move_event: "calendar.operations.move_event"]

        def handle(request, response)
          case move_event.call(record_id(request), request.params[:to])
            in Success(day) then done(request, response, :moved_event, date: i18n.l(day, format: :medium))
            in Failure(:invalid | :past => refusal) then done(request, response, refusal)
            in result then written(request, response, result, :moved_event)
          end
        end
      end
    end
  end
end
