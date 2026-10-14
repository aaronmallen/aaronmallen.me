# frozen_string_literal: true

module Spec
  module LinkedInAccounts
    def connect_linkedin(account_id: "member-ada", label: "Ada Lovelace", token: "li-token")
      Services::Slice["repos.connection_mutations"].add(
        provider: "linkedin", account_id:, label:, scopes: %w[openid profile w_member_social],
        credentials: { access_token: token, expires_at: Time.now.to_i + 3600 },
      )
    end

    def set_up_linkedin_client(credentials = { client_id: "li-id", client_secret: "li-secret" })
      allow(Hanami.app.settings).to receive(:linkedin).and_return(credentials)
      replace_component("linkedin.auth", LinkedIn::Providers::ClientProvider.auth(Hanami.app.settings))
      networks = Hanami.app["networks.all"]
      client = LinkedIn::Providers::ClientProvider.client(Hanami.app.settings)
      replace_component("networks.all", networks.merge(Blog::Types::NetworkName["linkedin"] => client).freeze)
    end
  end
end

RSpec.configure do |config|
  config.include Spec::LinkedInAccounts
end
