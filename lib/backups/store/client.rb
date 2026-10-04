# frozen_string_literal: true

require "aws-sdk-s3"

module Backups
  module Store
    class Client
      class Error < Backups::Error; end

      def initialize(bucket:, connection:)
        @bucket = bucket
        @connection = connection
      end

      def configured? = !connection.nil?

      def delete(key)
        return unless configured?

        request { connection.delete_object(bucket:, key:) }
        nil
      end

      def inspect = "#<#{self.class.name} configured=#{configured?}>"

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

      attr_reader :bucket, :connection

      def request
        yield
      rescue Aws::Errors::ServiceError, Seahorse::Client::NetworkingError => e
        raise Error, "The backup store failed: #{e.message}"
      end
    end
  end
end
