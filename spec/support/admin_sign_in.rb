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
    get "/admin/auth/github/callback", code: "code", state: start_admin_sign_in("github")
  end

  def start_admin_sign_in(provider)
    get "/admin/sign-in"
    form = Capybara.string(last_response.body).find("form[action='/admin/sign-in/#{provider}']")
    post "/admin/sign-in/#{provider}", _csrf_token: form.find("input[name='_csrf_token']", visible: :all).value
    Rack::Utils.parse_query(URI(last_response.location).query).fetch("state")
  end

  def stub_github_emails(email, primary: true, verified: true)
    stub_request(:get, "https://api.github.com/user/emails")
      .to_return(headers: { "Content-Type" => "application/json" }, body: [{ email:, primary:, verified: }].to_json)
  end

  def stub_github_sign_in
    connect_oauth_app
    stub_request(:post, "https://github.com/login/oauth/access_token")
      .to_return(headers: { "Content-Type" => "application/json" }, body: { access_token: "gho_token" }.to_json)
    stub_github_emails(Spec::AdminSession::EMAIL)
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
