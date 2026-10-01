# frozen_string_literal: true

Media::Slice.register_provider :store do
  start do
    register "store.client", Media::Providers::StoreProvider.client(target["settings"])
  end
end
