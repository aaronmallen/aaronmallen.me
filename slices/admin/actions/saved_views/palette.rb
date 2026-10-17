# frozen_string_literal: true

require "json"

module Admin
  module Actions
    module SavedViews
      class Palette < Action
        include Deps[list_palette_saved_views: "operations.list_palette_saved_views"]

        config.formats.accept :json

        def handle(_request, response)
          response.format = :json
          response.body = JSON.generate(rows: list_palette_saved_views.call)
        end

        private

        def require_sign_in(request, _response)
          halt :unauthorized unless auth_session(request).signed_in?
        end
      end
    end
  end
end
