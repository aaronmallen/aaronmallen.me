# auto_register: false
# frozen_string_literal: true

require "hanami/action/csrf_protection"
require "rack"

module MCP
  class BrowserAction < Action
    FORBIDDEN = 403
    ROBOTS = "noindex, nofollow"

    include Hanami::Action::CSRFProtection
    include CSRFToken
    include Deps[
      refused_view: "ui.views.authorizations.refused",
      rejected_view: "ui.views.authorizations.rejected",
      session_reader: "admin.auth.session_reader",
    ]

    verify_csrf_under_test

    before :harden

    private

    def admin_session(request) = session_reader.call(request)

    def authorization_params(request)
      request.params.to_h.merge(client_id: Blog::Types::UuidParam[request.params[:client_id]])
    end

    def handle_invalid_csrf_token(request, response) = reject_form(request, response)

    def harden(request, response)
      forbid_caching(request, response)
      response.headers["X-Robots-Tag"] = ROBOTS
    end

    def refuse(response, refusal)
      response.status = REJECTED
      response.render(refused_view, **refusal)
    end

    def reject_form(request, response)
      harden(request, response)
      halt FORBIDDEN, response.render(rejected_view)
    end

    def start_sign_in(request, response, session)
      session.return_to = request.fullpath
      response.redirect_to(routes.path(:admin_sign_in))
    end
  end
end
