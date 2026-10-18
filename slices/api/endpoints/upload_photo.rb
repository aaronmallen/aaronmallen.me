# frozen_string_literal: true

require "base64"
require "stringio"

module API
  module Endpoints
    class UploadPhoto < Endpoint
      CONTRACTS = [::Media::Contracts::PhotoContract].freeze
      ERRORS = "photo_upload.errors"
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
          in Success(photo) then Success(serialized(Serializers::Photo, photo, url: settings.site_url(photo.path)))
          in Failure[:invalid, { photo: [code, *] }] then refuse(code)
          in Failure[:unavailable] then Failure(Structs::Refusal.unavailable(message(:unavailable)))
          in Failure[reason] then refuse(reason)
        end
      end

      private

      def decoded(data)
        Base64.strict_decode64(data.match?(WHITESPACE) ? data.gsub(WHITESPACE, "") : data)
      rescue ArgumentError
        nil
      end

      def message(code) = i18n.t(code, scope: ERRORS, **::Media::Operations::UploadPhoto::LIMITS)

      def refuse(code) = invalid({ data: [message(code)] })

      def upload(bytes, filename) = bytes.empty? ? nil : { tempfile: StringIO.new(bytes), filename: }
    end
  end
end
