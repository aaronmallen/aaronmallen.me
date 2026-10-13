# frozen_string_literal: true

Hanami.app.register_provider :google, namespace: true do
  start do
    register :auth, Google::Providers::ClientProvider.auth(target["settings"])
    register :client, Google::Providers::ClientProvider.client(target["settings"])
  end
end
