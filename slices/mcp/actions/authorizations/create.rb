# frozen_string_literal: true

module MCP
  module Actions
    module Authorizations
      class Create < BrowserAction
        include Deps[authorize: "operations.authorize"]

        def handle(request, response)
          signed_in = admin_session(request).signed_in?
          decision = decision_from(request)

          case authorize.call(authorization_params(request), decision:, issuer:, signed_in:)
          in Success(url) then response.redirect_to(url)
          in Failure(Operations::Authorize::SIGN_IN) then reject_form(request, response)
          in Failure(Operations::Authorize::REFUSE, refusal) then refuse(response, refusal)
          in Failure(Operations::Authorize::REJECT, payload) then render_json(response, payload, status: REJECTED)
          else reject_json(response)
          end
        end

        private

        def decision_from(request) = Blog::Types::OAuthDecisionParam[request.params[:decision]]
      end
    end
  end
end
