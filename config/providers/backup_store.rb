# frozen_string_literal: true

Hanami.app.register_provider :backup_store do
  start do
    register "backup_store.client", ObjectStore::Provider.build(target["settings"].backup_store)
  end
end
