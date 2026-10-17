# frozen_string_literal: true

module Admin
  module Actions
    module Calendar
      class EventMenu < Action
        include Deps[calendar_queries: "calendar.repos.calendar_queries"]

        def handle(request, response)
          event = calendar_queries.event(record_id(request)) || halt(:not_found)
          day = Blog::Types::DateParam[request.params[:day]] || event.starts_on

          response.render(view, event:, day:)
        end
      end
    end
  end
end
