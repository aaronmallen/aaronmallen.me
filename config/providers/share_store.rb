# frozen_string_literal: true

Hanami.app.register_provider :share_store do
  start do
    register "share_store.client", ObjectStore::Provider.build(target["settings"].share_store)
  end
end
