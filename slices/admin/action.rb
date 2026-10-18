# auto_register: false
# frozen_string_literal: true

module Admin
  class Action < Blog::Action
    QUEUE_UNAVAILABLE = "queue_unavailable"

    include CSRFToken
    include Deps[
      "operations.build_navigation", "settings",
      not_found_view: "ui.views.not_found", rejected_view: "ui.views.forms.rejected",
    ]

    config.formats.accept :html
    config.handle_exception BodyParsingError => 400

    verify_csrf_under_test

    before :stamp_live, :require_sign_in

    private

    def allow_oauth_redirects(_request, response)
      policy = Slice.config.actions.content_security_policy.dup
      policy[:form_action] = "'self' https:"
      response.headers["Content-Security-Policy"] = policy.to_s
    end

    def auth_callback_url(provider) = routes.url(:admin_auth_callback, provider:).to_s

    def auth_session(request) = Auth::Session.for(request)

    def back_here(request) = auth_session(request).admin_return_path(request.params[:return_to])

    def back_to_section(request, route, section)
      back = back_here(request)
      return back if back.nil? || back.include?("#") || back.split("?").first != routes.path(route)

      "#{back}##{section}"
    end

    def end_session(request, response, return_to: nil)
      path = auth_session(request).sign_out(return_to)
      response.delete_cookie(Blog::SessionCookie::KEY, path: Blog::SessionCookie::PATH)
      path
    end

    def handle_invalid_csrf_token(_request, response)
      halt :forbidden, response.render(rejected_view)
    end

    def landing(request)
      number = page_number(request)
      return number if number == 1

      page = Blog::Structs::Page.new(number:, size: page_size)
      yield(page) ? number - 1 : number
    end

    def navigation(request) = request.env[UI::Navigated::KEY] ||= build_navigation.call(current_path: request.path)

    def not_found(response)
      response.format = :html
      halt :not_found, response.render(not_found_view)
    end

    def page_number(request) = Blog::Types::PageParam.call(request.params[:page]) { 1 }

    def page_size = settings.page_size[:admin]

    def picked_ids(request) = Array(request.params[:ids]).filter_map { Blog::Types::IdParam[it] }.uniq

    def record_id(request, key = :id) = Blog::Types::IdParam[request.params[key]] || halt(:not_found)

    def require_sign_in(request, response)
      return unless sign_in_required?

      session = auth_session(request)
      return if session.signed_in?

      session.return_to = request.fullpath if request.get?
      response.redirect_to(routes.path(:admin_sign_in))
    end

    def settle(response, result, key, path)
      case result
        in Success(_) then toast_back(response, key, path)
        in Failure(:queue_unavailable) then toast_back(response, QUEUE_UNAVAILABLE, path)
        in Failure[:invalid, errors] if block_given? then yield errors
        in Failure(:not_found) then halt :not_found
        else halt :internal_server_error
      end
    end

    def sign_in_required? = true

    def stamp_live(request, _response)
      request.env[Live::Clock::KEY] = Live::Clock.now
    end

    def toast(response, key, **)
      response.flash[UI::Components::Toast::FLASH_KEY] = i18n.t!(key, **)
    end

    def toast_back(response, key, path)
      toast(response, key)
      response.redirect_to(path)
    end

    def unprocessable(response, view, **)
      response.status = :unprocessable_content
      response.render(view, **)
    end
  end
end
