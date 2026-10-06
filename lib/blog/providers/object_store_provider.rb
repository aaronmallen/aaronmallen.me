# frozen_string_literal: true

require "aws-sdk-s3"
require "uri"

module Blog
  module Providers
    module ObjectStoreProvider
      CONNECT_TIMEOUT = 5
      RETRIES = 1
      WHEN_REQUIRED = "when_required"

      class << self
        def build(store, client:, read_timeout:)
          client.new(bucket: store[:bucket], connection: credentials?(store) ? s3(store, read_timeout) : nil)
        rescue ArgumentError, URI::Error
          client.new(bucket: nil, connection: nil)
        end

        private

        def credentials?(store) = store.values_at(:access_key, :bucket, :secret_key).all?

        def s3(store, read_timeout)
          Aws::S3::Client.new(
            access_key_id: store[:access_key],
            force_path_style: store[:path_style],
            http_open_timeout: CONNECT_TIMEOUT,
            http_read_timeout: read_timeout,
            region: store[:region],
            request_checksum_calculation: WHEN_REQUIRED,
            response_checksum_validation: WHEN_REQUIRED,
            retry_limit: RETRIES,
            secret_access_key: store[:secret_key],
            **store.slice(:endpoint).compact,
          )
        end
      end
    end
  end
end
