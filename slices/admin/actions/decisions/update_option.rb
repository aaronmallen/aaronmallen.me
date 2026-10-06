# frozen_string_literal: true

module Admin
  module Actions
    module Decisions
      class UpdateOption < Action
        SAVED = "decisions_page.toasts.option_saved"

        include PageForm
        include Deps[
          build_decision_page: "operations.build_decision_page",
          edit_decision_option: "decisions.operations.edit_decision_option",
          show_view: "ui.views.decisions.show",
        ]

        def handle(request, response)
          option_id = Blog::Types::IdParam[request.params[:option_id]] || halt(404)
          params = Blog::Types::Fields[request.params[:option]]

          result = edit_decision_option.call(record_id(request), option_id, params)

          case result
          in Failure[:invalid, errors]
            refuse_form(request, response, { name: :option, id: option_id, params:, errors: })
          else settle(response, result, SAVED, decision_path(request))
          end
        end
      end
    end
  end
end
