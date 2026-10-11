# frozen_string_literal: true

module Shares
  module Store
    class Client < Blog::ObjectStore::Client
      class Error < StandardError; end

      def put(key, body, content_type:)
        return unless configured?

        request { connection.put_object(bucket:, key:, body:, content_type:) }
        key
      end

      private

      def failure = "The share store failed"
    end
  end
end
