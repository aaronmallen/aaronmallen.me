# frozen_string_literal: true

Hanami.app.register_provider :networks, namespace: true do
  start do
    register :all, {
      Blog::Types::NetworkName["bluesky"] => Bluesky::Providers::ClientProvider.client(target["http"]),
      Blog::Types::NetworkName["linkedin"] => LinkedIn::Providers::ClientProvider.client(target["settings"]),
      Blog::Types::NetworkName["mastodon"] => Mastodon::Providers::ClientProvider.client(target["http"]),
    }.freeze
  end
end
