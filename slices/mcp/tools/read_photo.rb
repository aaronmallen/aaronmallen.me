# frozen_string_literal: true

require "json"

module MCP
  module Tools
    class ReadPhoto < Base
      DETAILS = %i[key width height byte_size].freeze

      description "See a photo the site keeps, whatever record names it or none: the picture itself, and its key, " \
                  "width, height and size in bytes. Pass the URL from a post, journal entry, task or comment, or " \
                  "the key at its end. Alt text lives in the Markdown that names the photo"
      endpoint

      class << self
        private

        def reply(payload, _server_context)
          Tool::Response.new(
            [
              Content::Image.new(payload.fetch(:data), payload.fetch(:content_type)).to_h,
              Content::Text.new(JSON.generate(payload.slice(*DETAILS))).to_h,
            ],
          )
        end
      end
    end
  end
end
