# auto_register: false
# frozen_string_literal: true

module Admin
  module Actions
    module Calendar
      class EventWrite < Action
        FIELDS = %i[title calendar date starts ends all_day place scope].freeze

        include Redirect
        include Deps[build_calendar_page: "operations.build_calendar_page", show_view: "ui.views.calendar.show"]

        private

        def refuse(request, response, errors, id: nil)
          params = request.params
          values = FIELDS.to_h { [it, Blog::Types::Text[params[it]]] }
          refused = { id:, menu: Blog::Types::Checkbox[params[:menu]], values:, errors: }

          response.status = :unprocessable_content
          response.render(show_view, **build_calendar_page.call(day: params[:day]), refused:)
        end
      end
    end
  end
end
