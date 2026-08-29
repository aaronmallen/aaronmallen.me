# frozen_string_literal: true

require "admin/providers/github_auth_provider"
require_relative "admin_session"

module AdminSignIn
  CSRF_SEED_PATH = "/admin/commits/0"

  def admin_csrf_token = @admin_csrf_token || session_csrf_token || seeded_csrf_token

  def sign_in_to_admin
    stub_github_sign_in
    @admin_csrf_token = Spec::AdminSession.new_csrf_token
    set_cookie("#{Blog::SessionCookie::KEY}=#{Spec::AdminSession.cookie(csrf_token: @admin_csrf_token)}")
  end

  def sign_in_to_admin_with_github
    stub_github_sign_in
    get "/admin/sign-in"
    state = Rack::Utils.parse_query(URI(last_response.location).query).fetch("state")
    get "/admin/auth/github/callback", code: "code", state:
  end

  def stub_github_sign_in
    connect_oauth_app
    stub_request(:post, "https://github.com/login/oauth/access_token")
      .to_return(headers: { "Content-Type" => "application/json" }, body: { access_token: "gho_token" }.to_json)
    stub_request(:get, "https://api.github.com/user")
      .to_return(headers: { "Content-Type" => "application/json" }, body: { id: 931_094 }.to_json)
  end

  private

  def seeded_csrf_token
    get CSRF_SEED_PATH
    session_csrf_token
  end

  def session_csrf_token
    last_request.env["rack.session"]&.[](Spec::AdminSession::CSRF_TOKEN)
  rescue Rack::Test::Error
    nil
  end
end

RSpec.configure do |config|
  config.include AdminSignIn, type: :request
end
