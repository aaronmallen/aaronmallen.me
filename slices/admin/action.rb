# auto_register: false
# frozen_string_literal: true

module Admin
  class Action < Blog::Action
    include CSRFToken
    include Deps[not_found_view: "ui.views.not_found", rejected_view: "ui.views.forms.rejected"]

    config.formats.accept :html
    config.handle_exception BodyParsingError => 400

    verify_csrf_under_test

    before :require_sign_in

    private

    def auth_session(request) = Auth::Session.for(request)

    def end_session(request, response, return_to: nil)
      path = auth_session(request).sign_out(return_to)
      response.delete_cookie(Blog::SessionCookie::KEY, path: Blog::SessionCookie::PATH)
      path
    end

    def github_callback_url = routes.url(:admin_github_callback).to_s

    def github_service_callback_url = routes.url(:admin_github_service_callback).to_s

    def handle_invalid_csrf_token(_request, response)
      halt 403, response.render(rejected_view)
    end

    def mastodon_service_callback_url = routes.url(:admin_mastodon_service_callback).to_s

    def not_found(response)
      response.format = :html
      halt 404, response.render(not_found_view)
    end

    def record_id(request) = Blog::Types::IdParam[request.params[:id]] || halt(404)

    def require_sign_in(request, response)
      return unless sign_in_required?

      session = auth_session(request)
      return if session.signed_in?

      session.return_to = request.fullpath if request.get?
      response.redirect_to(routes.path(:admin_sign_in))
    end

    def settle(response, result, key, path)
      case result
        in Success(_)
          toast(response, key)
          response.redirect_to(path)
        in Failure(:not_found) then halt 404
        else halt 500
      end
    end

    def sign_in_required? = true

    def toast(response, key, **)
      response.flash[UI::Components::Toast::FLASH_KEY] = i18n.t!(key, **)
    end
  end
end
