# auto_register: false
# frozen_string_literal: true

module Admin
  class SavedViewAction < Action
    INVALID = "saved_views_page.toasts.invalid"
    MAX_NAME = ::SavedViews::Contracts::SavedViewContract::MAX_NAME

    private

    def answer(request, response, key, **)
      toast(response, key, **)
      response.redirect_to(return_path(request))
    end

    def invalid(request, response) = answer(request, response, INVALID, max: MAX_NAME)

    def name_params(request) = { name: Blog::Types::Fields[request.params[:saved_view]][:name] }

    def return_path(request)
      back_here(request) || routes.path(:admin_root)
    end
  end
end
