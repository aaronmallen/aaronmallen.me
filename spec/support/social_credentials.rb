# frozen_string_literal: true

module SocialCredentials
  ALL_KEYS = %w[networks.all social.networks.all].freeze
  BLUESKY = { app_password: "secret", handle: "ada.example" }.freeze
  MASTODON = { access_token: "token", url: "https://ruby.social" }.freeze

  def connect_bluesky(credentials = BLUESKY, account_id: "did:plc:ada")
    disconnect_bluesky
    Services::Slice["repos.connection_mutations"]
      .add(provider: "bluesky", account_id:, label: "@#{credentials[:handle]}", credentials:)
  end

  def connect_social_networks(bluesky: BLUESKY, mastodon: MASTODON)
    Social::Slice.start(:networks)
    bluesky.empty? ? disconnect_bluesky : connect_bluesky(bluesky)
    allow(Hanami.app.settings).to receive_messages(mastodon:)
    replace_social_clients
  end

  private

  def disconnect_bluesky = Services::Slice["relations.service_connections"].where(provider: "bluesky").delete

  def replace_social_clients
    scan_links = Social::Slice["operations.scan_links"]
    bluesky = Social::Providers::NetworksProvider.bluesky(
      Services::Slice["repos.connection_queries"], Hanami.app["http"],
      scan_links:, scan_tags: Social::Slice["operations.scan_tags"],
    )
    mastodon = Social::Providers::NetworksProvider.mastodon(Hanami.app["settings"], Hanami.app["http"], scan_links:)
    all = Social::Providers::NetworksProvider.all(bluesky, mastodon)

    ALL_KEYS.each { replace_component(it, all) }
  end
end

RSpec.configure do |config|
  config.include SocialCredentials
end
