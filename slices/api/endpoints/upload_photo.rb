# frozen_string_literal: true

require "base64"
require "stringio"

module API
  module Endpoints
    class UploadPhoto < Endpoint
      MESSAGES = {
        "blank" => "photo_upload.errors.blank",
        "large" => "photo_upload.errors.large",
        "type" => "photo_upload.errors.type",
        oversized: "photo_upload.errors.oversized",
        unavailable: "photo_upload.errors.unavailable",
        unreadable: "photo_upload.errors.unreadable",
      }.freeze
      UNAVAILABLE = true
      WHITESPACE = /\s/

      SCHEMA = {
        additionalProperties: false,
        properties: {
          data: { type: "string", description: "the photo's bytes in base64" },
          filename: { type: "string", description: "the photo's file name; the site judges its type by its bytes" },
        },
        required: %w[data filename],
      }.freeze

      REPLY = Serializers::Photo.reference

      include Deps["i18n", upload_photo: "media.operations.upload_photo"]

      def handle(data:, filename:)
        bytes = decoded(data)
        return refuse(:unreadable) unless bytes

        case upload_photo.call(Blog::Types::UploadParam[upload(bytes, filename)])
          in Success(photo) then Success(serialized(Serializers::Photo, photo))
          in Failure[:invalid, { photo: [code, *] }] then refuse(code)
          in Failure[:unavailable] then Failure(Refusal.unavailable(message(:unavailable)))
          in Failure[reason] then refuse(reason)
        end
      end

      private

      def decoded(data)
        Base64.strict_decode64(data.gsub(WHITESPACE, ""))
      rescue ArgumentError
        nil
      end

      def message(code) = i18n.t(MESSAGES.fetch(code))

      def refuse(code) = invalid({ data: [message(code)] })

      def upload(bytes, filename) = bytes.empty? ? nil : { tempfile: StringIO.new(bytes), filename: }
    end
  end
end
