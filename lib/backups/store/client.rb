# frozen_string_literal: true

module Backups
  module Store
    class Client < Blog::ObjectStore::Client
      class Error < Backups::Error; end

      def keys(prefix:)
        return [] unless configured?

        request { connection.list_objects_v2(bucket:, prefix:).flat_map { it.contents.map(&:key) } }
      end

      def upload(key, path)
        return unless configured?

        File.open(path, "rb") { |file| request { connection.put_object(bucket:, key:, body: file) } }
        key
      end

      private

      def failure = "The backup store failed"
    end
  end
end
