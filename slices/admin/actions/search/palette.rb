# frozen_string_literal: true

require "json"

module Admin
  module Actions
    module Search
      class Palette < Action
        UNAUTHORIZED = 401

        include Deps[search_palette: "operations.search_palette"]

        config.formats.accept :json

        before :forbid_caching

        def handle(request, response)
          response.format = :json
          response.body = JSON.generate(groups: search_palette.call(request.params[:q]))
        end

        private

        def require_sign_in(request, _response)
          halt UNAUTHORIZED unless auth_session(request).signed_in?
        end
      end
    end
  end
end
