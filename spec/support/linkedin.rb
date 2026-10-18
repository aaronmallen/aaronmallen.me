# frozen_string_literal: true

module Spec
  module LinkedInAccounts
    ANALYTICS = "https://api.linkedin.com/rest/memberCreatorPostAnalytics"
    IMAGES = "https://api.linkedin.com/rest/images?action=initializeUpload"
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

    def linkedin_analytics = ANALYTICS

    def linkedin_images = IMAGES

    def linkedin_posts = POSTS

    def linkedin_upload_url(index) = "https://www.linkedin.com/dms-uploads/img-#{index}/uploaded-image/0?ut=up"

    def set_up_linkedin_client(credentials = { client_id: "li-id", client_secret: "li-secret" })
      allow(Hanami.app.settings).to receive(:linkedin).and_return(credentials)
      replace_component("linkedin.auth", LinkedIn::Providers::ClientProvider.auth(Hanami.app.settings))
      networks = Hanami.app["social_networks.all"]
      client = LinkedIn::Providers::ClientProvider.client(Hanami.app.settings, Hanami.app["http"])
      replace_component("social_networks.all", networks.merge(Blog::Types::NetworkName["linkedin"] => client).freeze)
    end

    def stub_linkedin(*ids)
      stub_request(:post, POSTS).to_return(*ids.map { { status: 201, headers: { "x-restli-id" => it } } })
    end

    def stub_linkedin_engagement(likes: 0, replies: 0, reposts: 0)
      { "REACTION" => likes, "COMMENT" => replies, "RESHARE" => reposts }.each do |type, count|
        response = json_response(elements: [{ count:, metricType: type }])
        stub_request(:get, ANALYTICS).with(query: hash_including("queryType" => type)).to_return(**response)
      end
    end

    def stub_linkedin_images
      count = 0
      stub_request(:post, IMAGES).to_return do
        count += 1
        json_response(value: { image: "urn:li:image:#{count}", uploadUrl: linkedin_upload_url(count) })
      end
      stub_request(:put, %r{\Ahttps://www\.linkedin\.com/dms-uploads/}).to_return(status: 201)
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
