# frozen_string_literal: true

module SocialCredentials
  ALL_KEYS = %w[networks.all social.networks.all].freeze
  BLUESKY = { app_password: "secret", handle: "ada.example" }.freeze
  MASTODON = { access_token: "token", url: "https://ruby.social" }.freeze

  def connect_social_networks(bluesky: BLUESKY, mastodon: MASTODON)
    Social::Slice.start(:networks)
    allow(Hanami.app.settings).to receive_messages(bluesky:, mastodon:)
    replace_social_clients
  end

  private

  def replace_social_clients
    bluesky = Social::Providers::NetworksProvider.bluesky(Hanami.app["settings"], Hanami.app["http"])
    mastodon = Social::Providers::NetworksProvider.mastodon(Hanami.app["settings"], Hanami.app["http"])
    all = Social::Providers::NetworksProvider.all(bluesky, mastodon)

    ALL_KEYS.each { replace_component(it, all) }
  end
end

RSpec.configure do |config|
  config.include SocialCredentials
end
