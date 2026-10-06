# frozen_string_literal: true

module Admin
  module Actions
    module SavedViewReturn
      INVALID = "saved_views_page.toasts.invalid"

      private

      def answer(request, response, key)
        toast(response, key)
        response.redirect_to(return_path(request))
      end

      def name_params(request) = { name: Blog::Types::Fields[request.params[:saved_view]][:name] }

      def return_path(request)
        auth_session(request).admin_return_path(request.params[:return_to]) || routes.path(:admin_root)
      end
    end
  end
end
