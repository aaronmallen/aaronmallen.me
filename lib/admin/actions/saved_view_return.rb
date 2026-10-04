# frozen_string_literal: true

module Admin
  module Actions
    module SavedViewReturn
      INVALID = "saved_views_page.toasts.invalid"

      private

      def answer(request, response, key)
        toast(response, key)
        back = auth_session(request).admin_return_path(request.params[:return_to])
        response.redirect_to(back || routes.path(:admin_root))
      end

      def name_params(request) = { name: Blog::Types::Fields[request.params[:saved_view]][:name] }
    end
  end
end
