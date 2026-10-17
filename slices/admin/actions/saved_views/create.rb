# frozen_string_literal: true

module Admin
  module Actions
    module SavedViews
      class Create < SavedViewAction
        SAVED = "saved_views_page.toasts.saved"

        include Deps[create_saved_view: "saved_views.operations.create_saved_view"]

        def handle(request, response)
          params = request.params

          case create_saved_view.call(**name_params(request), screen: params[:screen], filters: params[:filters])
            in Success(_) then answer(request, response, SAVED)
            in Failure[:invalid, _] then invalid(request, response)
            else halt :internal_server_error
          end
        end
      end
    end
  end
end
