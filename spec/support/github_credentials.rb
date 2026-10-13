# frozen_string_literal: true

module GitHubCredentials
  OAUTH_APP = { client_id: "client-id", client_secret: "client-secret" }.freeze

  def connect_github(**credentials)
    @github_credentials = credentials
    allow(Hanami.app.settings).to receive(:github).and_return(credentials)
    replace_github_components
  end

  def connect_github_account(access_token: "ghp_token", account_id: "931094", label: "@aaronmallen", scopes: ["repo"])
    Services::Slice["repos.connection_mutations"]
      .add(provider: "github", account_id:, label:, credentials: { access_token: }, scopes:)
  end

  def connect_oauth_app = connect_github(**@github_credentials.to_h, **OAUTH_APP)

  def disconnect_github
    Services::Slice["relations.service_connections"].where(provider: "github").delete
    connect_github(**OAUTH_APP)
  end

  private

  def replace_github_components
    replace_component("github.auth", GitHub::Providers::ClientProvider.auth(Hanami.app["settings"]))
    replace_component("github.client", GitHub::Providers::ClientProvider.client(Hanami.app["http"]))
  end
end

RSpec.configure do |config|
  config.include GitHubCredentials
end
