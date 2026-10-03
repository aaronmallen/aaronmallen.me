# frozen_string_literal: true

module Admin
  module Actions
    module Calendar
      class Show < Action
        include Deps[build_calendar_page: "operations.build_calendar_page"]

        def handle(request, response)
          params = request.params

          response.render(view, **build_calendar_page.call(month: params[:month], day: params[:day]))
        end
      end
    end
  end
end
