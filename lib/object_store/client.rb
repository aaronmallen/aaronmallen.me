# frozen_string_literal: true

require "aws-sdk-s3"

module ObjectStore
  class Client
    class Error < StandardError; end

    Head = Data.define(:content_length, :content_type)
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

    def exists?(key) = !head(key).nil?

    def get(key)
      return unless configured?

      response = request { connection.get_object(bucket:, key:) }
      response && Stored.new(body: response.body.read, content_type: response.content_type)
    end

    def head(key)
      return unless configured?

      response = request { connection.head_object(bucket:, key:) }
      response && Head.new(content_length: response.content_length, content_type: response.content_type)
    end

    def inspect = "#<#{self.class.name} configured=#{configured?}>"

    def keys(prefix:)
      return [] unless configured?

      request { connection.list_objects_v2(bucket:, prefix:).flat_map { it.contents.map(&:key) } }
    end

    def put(key, body, content_type: nil)
      return unless configured?

      request { connection.put_object({ bucket:, key:, body:, content_type: }.compact) }
      key
    end

    def stream(key, range: nil, &)
      return unless configured?

      request { connection.get_object({ bucket:, key:, range: }.compact, &) }
      nil
    end

    def upload(key, path) = File.open(path, "rb") { put(key, it) }

    private

    attr_reader :bucket, :connection

    def request
      yield
    rescue Aws::S3::Errors::NoSuchKey, Aws::S3::Errors::NotFound
      nil
    rescue Aws::Errors::ServiceError, Seahorse::Client::NetworkingError => e
      raise Error, "The #{bucket} store failed: #{e.message}"
    end
  end
end
