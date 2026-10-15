# frozen_string_literal: true

module Admin
  module Actions
    module Decisions
      class UpdateOption < PageAction
        SAVED = "decisions_page.toasts.option_saved"

        include Deps[edit_decision_option: "decisions.operations.edit_decision_option"]

        def handle(request, response)
          option_id = record_id(request, :option_id)
          params = Blog::Types::Fields[request.params[:option]]

          result = edit_decision_option.call(record_id(request), option_id, params)

          settle(response, result, SAVED, decision_path(request)) do |errors|
            refuse_form(request, response, { name: :option, id: option_id, params:, errors: })
          end
        end
      end
    end
  end
end
