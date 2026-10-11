# frozen_string_literal: true

Shares::Slice.register_provider :share_store do
  start do
    register "share_store.client", Shares::Providers::StoreProvider.client(target["settings"])
  end
end
