# frozen_string_literal: true

module Media
  module Providers
    module StoreProvider
      READ_TIMEOUT = 30

      class << self
        def client(settings)
          Blog::Providers::ObjectStoreProvider.build(
            settings.media_store, client: Store::Client, read_timeout: READ_TIMEOUT,
          )
        end
      end
    end
  end
end
