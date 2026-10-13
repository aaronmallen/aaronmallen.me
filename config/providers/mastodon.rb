# frozen_string_literal: true

Hanami.app.register_provider :mastodon, namespace: true do
  start do
    register :auth, Mastodon::Providers::ClientProvider.auth(target["settings"])
  end
end
