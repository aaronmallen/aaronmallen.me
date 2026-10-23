# frozen_string_literal: true

Hanami.app.register_provider :linear, namespace: true do
  start do
    register :client, Linear::Providers::ClientProvider.client(target["settings"], target["http"])
  end
end
