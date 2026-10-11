# auto_register: false
# frozen_string_literal: true

module Admin
  module Actions
    module Decisions
      class PageAction < Action
        include PageForm
        include Deps[build_decision_page: "operations.build_decision_page", show_view: "ui.views.decisions.show"]

        private

        def refuse_form(request, response, form)
          page = build_decision_page.call(record_id(request), form:)
          halt 404 unless page

          response.status = 422
          response.render(show_view, **page)
        end
      end
    end
  end
end
