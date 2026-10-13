# frozen_string_literal: true

Hanami.app.register_provider :github, namespace: true do
  start do
    register :auth, GitHub::Providers::ClientProvider.auth(target["settings"])
    register :client, GitHub::Providers::ClientProvider.client(target["http"])
  end
end
