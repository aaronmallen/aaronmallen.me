# frozen_string_literal: true

require "base64"
require "json"

module MCP
  module Tools
    class ReadPhoto < Base
      SCHEMA = {
        additionalProperties: false,
        properties: { photo: { type: "string", description: "the photo's URL, as upload_photo gives it, or its key" } },
        required: ["photo"],
      }.freeze
      UNAVAILABLE = "the photo store is not set up or did not answer; try again later"

      description "See a photo the site keeps, whatever record names it or none: the picture itself, and its key, " \
                  "width, height and size in bytes. Pass the URL from a post, journal entry, task or comment, or " \
                  "the key at its end. Alt text lives in the Markdown that names the photo"
      input_schema(SCHEMA)
      scope Blog::Types::OAuthScope["read"]

      class << self
        def call(photo:, server_context:)
          case dep(:read_photo, server_context).call(photo)
            in Success(read) then shown(read.photo, read.stored)
            in Failure[:missing, key] then refuse("no photo has the key #{key}")
            in Failure[:unavailable] then refuse(UNAVAILABLE)
          end
        end

        private

        def details(photo) = { key: photo.key, width: photo.width, height: photo.height, byte_size: photo.byte_size }

        def shown(photo, stored)
          Tool::Response.new(
            [
              Content::Image.new(Base64.strict_encode64(stored.body), stored.content_type).to_h,
              Content::Text.new(JSON.generate(details(photo))).to_h,
            ],
          )
        end
      end
    end
  end
end
