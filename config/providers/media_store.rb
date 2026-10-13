# frozen_string_literal: true

Hanami.app.register_provider :media_store do
  start do
    register "media_store.client", ObjectStore::Provider.build(target["settings"].media_store)
  end
end
