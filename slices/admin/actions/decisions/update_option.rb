# frozen_string_literal: true

module Admin
  module Actions
    module Decisions
      class UpdateOption < Action
        SAVED = "decisions_page.toasts.option_saved"

        include PageForm
        include Deps[
          decision_by_id: "decisions.queries.by_id",
          edit_decision_option: "decisions.operations.edit_decision_option",
          show_view: "ui.views.decisions.show",
        ]

        def handle(request, response)
          option_id = Blog::Types::IdParam[request.params[:option_id]] || halt(404)
          params = Blog::Types::Fields[request.params[:option]]

          case edit_decision_option.call(record_id(request), option_id, params)
          in Success(_) then to_decision(request, response, SAVED)
          in Failure(:not_found) then halt 404
          in Failure[:invalid, errors]
            refuse_form(request, response, { name: :option, id: option_id, params:, errors: })
          else halt 500
          end
        end
      end
    end
  end
end
