# frozen_string_literal: true

require "admin/providers/github_auth_provider"

module GitHubCredentials
  CLIENT_KEYS = %w[github.client record.github.client].freeze
  OAUTH_APP = { client_id: "client-id", client_secret: "client-secret" }.freeze

  def connect_github(**credentials)
    @github_credentials = credentials
    Admin::Slice.start(:github)
    Record::Slice.start(:github)
    allow(Hanami.app.settings).to receive(:github).and_return(credentials)
    replace_github_components
  end

  def connect_oauth_app = connect_github(**@github_credentials.to_h, **OAUTH_APP)

  def disconnect_github = connect_github(**OAUTH_APP)

  private

  def replace_github_components
    settings = Hanami.app["settings"]
    client = Record::Providers::GitHubProvider.client(settings, Hanami.app["http"])

    replace_component("github.auth", Admin::Providers::GitHubAuthProvider.auth(settings))
    CLIENT_KEYS.each { replace_component(it, client) }
  end
end

RSpec.configure do |config|
  config.include GitHubCredentials
end
