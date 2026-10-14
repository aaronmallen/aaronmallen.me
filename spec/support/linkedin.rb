# frozen_string_literal: true

module Spec
  module LinkedInAccounts
    POSTS = "https://api.linkedin.com/rest/posts"
    SCOPES = %w[openid profile w_member_social].freeze

    def connect_linkedin(
      account_id: "member-ada", label: "Ada Lovelace", token: "li-token",
      scopes: SCOPES, expires_at: nil, lapses_at: nil
    )
      Services::Slice["repos.connection_mutations"].add(
        provider: "linkedin", account_id:, label:, scopes:,
        credentials: { access_token: token, expires_at: expires_at || (Time.now.to_i + 3600) }, lapses_at:,
      )
    end

    def linkedin_posts = POSTS

    def set_up_linkedin_client(credentials = { client_id: "li-id", client_secret: "li-secret" })
      allow(Hanami.app.settings).to receive(:linkedin).and_return(credentials)
      replace_component("linkedin.auth", LinkedIn::Providers::ClientProvider.auth(Hanami.app.settings))
      networks = Hanami.app["networks.all"]
      client = LinkedIn::Providers::ClientProvider.client(Hanami.app.settings, Hanami.app["http"])
      replace_component("networks.all", networks.merge(Blog::Types::NetworkName["linkedin"] => client).freeze)
    end

    def stub_linkedin(*ids)
      stub_request(:post, POSTS).to_return(*ids.map { { status: 201, headers: { "x-restli-id" => it } } })
    end

    def stub_linkedin_recent(*commentaries)
      elements = commentaries.each_with_index.map { |commentary, index| { id: "urn:li:share:#{index}", commentary: } }

      stub_request(:get, POSTS).with(query: hash_including("q" => "author")).to_return(**json_response(elements:))
    end
  end
end

RSpec.configure do |config|
  config.include Spec::LinkedInAccounts
end
