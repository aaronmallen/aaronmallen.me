# frozen_string_literal: true

module MCP
  module Actions
    module Authorizations
      class New < BrowserAction
        FIELDS = %i[
          client_id code_challenge code_challenge_method redirect_uri resource response_type scope state
        ].freeze

        include Deps[authorize: "operations.authorize"]

        def handle(request, response)
          session = admin_session(request)
          params = authorization_params(request)

          case authorize.call(params, issuer:, signed_in: session.signed_in?)
            in Failure(Operations::Authorize::SIGN_IN) then start_sign_in(request, response, session)
            in Failure(Operations::Authorize::CONFIRM, asking) then confirm(response, params, asking)
            in Failure(Operations::Authorize::REFUSE, refusal) then refuse(response, refusal)
            in Failure(Operations::Authorize::REJECT, payload) then render_json(response, payload, status: REJECTED)
            else reject_json(response)
          end
        end

        private

        def confirm(response, params, asking)
          response.render(view, fields: params.slice(*FIELDS).compact.transform_keys(&:to_s), **asking)
        end
      end
    end
  end
end
