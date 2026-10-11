# frozen_string_literal: true

module Shares
  module Providers
    module StoreProvider
      READ_TIMEOUT = 300

      class << self
        def client(settings)
          Blog::Providers::ObjectStoreProvider.build(
            settings.share_store, client: Store::Client, read_timeout: READ_TIMEOUT,
          )
        end
      end
    end
  end
end
