# frozen_string_literal: true

Hanami.app.register_provider :social_networks, namespace: true do
  start do
    http = target["http"]
    pages = target["page_fetcher.link_preview"]
    settings = target["settings"]

    register :all, {
      Blog::Types::NetworkName["bluesky"] => Bluesky::Providers::ClientProvider.client(settings, http, pages),
      Blog::Types::NetworkName["linkedin"] => LinkedIn::Providers::ClientProvider.client(settings, http),
      Blog::Types::NetworkName["mastodon"] => Mastodon::Providers::ClientProvider.client(settings, http),
    }.freeze
  end
end
