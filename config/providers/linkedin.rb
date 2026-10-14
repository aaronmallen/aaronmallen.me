# frozen_string_literal: true

Hanami.app.register_provider :linkedin, namespace: true do
  start do
    register :auth, LinkedIn::Providers::ClientProvider.auth(target["settings"])
  end
end
