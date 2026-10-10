# frozen_string_literal: true

module Media
  module Store
    class Client < Blog::ObjectStore::Client
      class Error < StandardError; end

      Stored = Data.define(:body, :content_type)

      def get(key)
        return unless configured?

        response = request { connection.get_object(bucket:, key:) }
        response && Stored.new(body: response.body.read, content_type: response.content_type)
      end

      def put(key, body, content_type:)
        return unless configured?

        request { connection.put_object(bucket:, key:, body:, content_type:) }
        key
      end

      private

      def failure = "The media store failed"
    end
  end
end
