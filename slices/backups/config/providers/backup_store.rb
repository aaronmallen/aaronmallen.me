# frozen_string_literal: true

Backups::Slice.register_provider :backup_store do
  start do
    register "backup_store.client", Backups::Providers::StoreProvider.client(target["settings"])
  end
end
