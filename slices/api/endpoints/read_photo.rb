# frozen_string_literal: true

require "base64"

module API
  module Endpoints
    class ReadPhoto < Endpoint
      FINDS = true
      STORE_DOWN = "the photo store is not set up or did not answer; try again later"
      UNAVAILABLE = true

      SCHEMA = {
        additionalProperties: false,
        properties: { photo: { type: "string", description: "the photo's URL, as upload_photo gives it, or its key" } },
        required: ["photo"],
      }.freeze

      REPLY = Helpers::Schema.object(
        {
          key: Helpers::Schema::STRING,
          width: Helpers::Schema::INTEGER,
          height: Helpers::Schema::INTEGER,
          byte_size: Helpers::Schema::INTEGER,
          content_type: Helpers::Schema::STRING,
          data: { type: "string", description: "the photo's bytes in base64" },
        },
      ).freeze

      include Deps[read_photo: "media.operations.read_photo"]

      def handle(photo:)
        case read_photo.call(photo)
          in Success(read) then Success(answered(read.photo, read.stored))
          in Failure[:missing, key] then not_found("no photo has the key #{key}")
          in Failure[:unavailable] then Failure(Structs::Refusal.unavailable(STORE_DOWN))
        end
      end

      private

      def answered(photo, stored)
        {
          key: photo.key, width: photo.width, height: photo.height, byte_size: photo.byte_size,
          content_type: stored.content_type, data: Base64.strict_encode64(stored.body),
        }
      end
    end
  end
end
