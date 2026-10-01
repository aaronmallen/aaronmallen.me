# frozen_string_literal: true

require "aws-sdk-s3"

module Media
  module Store
    class Client
      class Error < Media::Error; end

      Stored = Data.define(:body, :content_type)

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

      def get(key)
        return unless configured?

        response = request { connection.get_object(bucket:, key:) }
        response && Stored.new(body: response.body.read, content_type: response.content_type)
      end

      def inspect = "#<#{self.class.name} configured=#{configured?}>"

      def put(key, body, content_type:)
        return unless configured?

        request { connection.put_object(bucket:, key:, body:, content_type:) }
        key
      end

      private

      attr_reader :bucket, :connection

      def request
        yield
      rescue Aws::S3::Errors::NoSuchKey
        nil
      rescue Aws::Errors::ServiceError, Seahorse::Client::NetworkingError => e
        raise Error, "The media store failed: #{e.message}"
      end
    end
  end
end
