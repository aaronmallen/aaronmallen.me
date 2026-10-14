# frozen_string_literal: true

Hanami.app.register_provider :networks, namespace: true do
  start do
    http = target["http"]

    register :all, {
      Blog::Types::NetworkName["bluesky"] => Bluesky::Providers::ClientProvider.client(http),
      Blog::Types::NetworkName["linkedin"] => LinkedIn::Providers::ClientProvider.client(target["settings"], http),
      Blog::Types::NetworkName["mastodon"] => Mastodon::Providers::ClientProvider.client(http),
    }.freeze
  end
end
