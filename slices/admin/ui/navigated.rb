# frozen_string_literal: true

module Admin
  module UI
    module Navigated
      KEY = "admin.navigation"

      private

      def navigation
        return unless Auth::Session.for(request).signed_in?

        request.env[KEY] ||= slice["operations.build_navigation"].call(current_path: request.path)
      end
    end
  end
end
