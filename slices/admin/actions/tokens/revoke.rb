# frozen_string_literal: true

module Admin
  module Actions
    module Tokens
      class Revoke < Action
        REVOKED = "tokens_page.toasts.revoked"

        include Deps[revoke_token: "api.operations.revoke_token"]

        def handle(request, response)
          halt 404 if revoke_token.call(record_id(request)).failure?

          toast(response, REVOKED)
          response.redirect_to(routes.path(:admin_tokens))
        end
      end
    end
  end
end
