# frozen_string_literal: true

require "aws-sdk-s3"

module Blog
  module ObjectStore
    class Client
      class Error < StandardError; end

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

      private

      attr_reader :bucket, :connection

      def failure = "The object store failed"

      def request
        yield
      rescue Aws::S3::Errors::NoSuchKey
        nil
      rescue Aws::Errors::ServiceError, Seahorse::Client::NetworkingError => e
        raise self.class::Error, "#{failure}: #{e.message}"
      end
    end
  end
end
