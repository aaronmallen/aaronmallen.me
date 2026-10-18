# frozen_string_literal: true

module SocialCredentials
  BLUESKY = { app_password: "secret", handle: "ada.example" }.freeze
  MASTODON = { access_token: "token", host: "ruby.social" }.freeze

  def connect_another_bluesky(handle: "grace.example", account_id: "did:plc:grace")
    Services::Slice["repos.connection_mutations"].add(
      provider: "bluesky", account_id:, label: "@#{handle}", credentials: { app_password: "other", handle: },
    )
  end

  def connect_another_mastodon(host: "hachyderm.io", access_token: "other")
    Services::Slice["repos.connection_mutations"].add(
      provider: "mastodon", host:, account_id: "2", label: "@ada@#{host}", credentials: { access_token: },
      scopes: %w[write:statuses write:media read:accounts read:search read:statuses],
    )
  end

  def connect_bluesky(credentials = BLUESKY, account_id: "did:plc:ada")
    disconnect_bluesky
    Services::Slice["repos.connection_mutations"]
      .add(provider: "bluesky", account_id:, label: "@#{credentials[:handle]}", credentials:)
  end

  def connect_social_networks(bluesky: BLUESKY, mastodon: MASTODON)
    bluesky.empty? ? disconnect_bluesky : connect_bluesky(bluesky)
    connect_mastodon(**mastodon)
    replace_social_clients
  end

  def remember_social_accounts
    ids = Services::Slice["relations.service_connections"].pluck(:id).map(&:to_s)
    visit "/admin/social"
    execute_script("localStorage.setItem('social:accounts', arguments[0])", JSON.generate(ids))
    visit "/admin/social"
  end

  def social_account(network) = Services::Slice["repos.connection_queries"].for(network).first

  private

  def connect_mastodon(access_token: nil, host: nil)
    Services::Slice["relations.service_connections"].where(provider: "mastodon").delete
    return unless access_token

    Services::Slice["repos.connection_mutations"].add(
      provider: "mastodon", host:, account_id: "1", label: "@aaronmallen@#{host}", credentials: { access_token: },
      scopes: %w[write:statuses write:media read:accounts read:search read:statuses],
    )
  end

  def disconnect_bluesky = Services::Slice["relations.service_connections"].where(provider: "bluesky").delete

  def replace_social_clients
    pages = Hanami.app["page_fetcher.link_preview"]

    replace_component("networks.all", {
      "bluesky" => Bluesky::Providers::ClientProvider.client(Hanami.app["http"], pages),
      "linkedin" => LinkedIn::Providers::ClientProvider.client(Hanami.app.settings, Hanami.app["http"]),
      "mastodon" => Mastodon::Providers::ClientProvider.client(Hanami.app["http"]),
    }.freeze)
  end
end

RSpec.configure do |config|
  config.include SocialCredentials
end
