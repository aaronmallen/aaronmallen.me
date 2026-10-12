# frozen_string_literal: true

module Admin
  module Actions
    module Calendar
      class ShowCalendars < Action
        include Move
        include Deps[show_calendars: "calendar.operations.show_calendars"]

        def handle(request, response)
          show_calendars.call(request.params[:shown], preset: request.params[:preset])
          done(request, response, :calendars)
        end
      end
    end
  end
end
