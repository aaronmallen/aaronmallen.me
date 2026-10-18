# frozen_string_literal: true

require "base64"
require "stringio"

module API
  module Helpers
    module Upload
      COMPLAINTS = {
        content_type: { Blog::Contract::FORMAT => "content_type is a media type, such as image/png" },
        filename: { Blog::Contract::FORMAT => "filename is a bare name, with no slash, and not . or .." },
      }.freeze
      DATA = { type: "string", description: "the file's bytes in base64" }.freeze
      FILE = Schema.object(
        { data: DATA, filename: { type: "string", description: "the file's name, as the link hands it out" } },
        optional: {
          content_type: { type: "string",
                          description: "the file's media type; application/octet-stream when left out" },
        },
      ).freeze
      NOT_BASE64 = "is not base64"
      STORE_DOWN = "the share store is not set up or did not answer; try again later"
      WHITESPACE = /\s/

      module_function

      def decoded(data)
        Base64.strict_decode64(data.match?(WHITESPACE) ? data.gsub(WHITESPACE, "") : data)
      rescue ArgumentError
        nil
      end

      def file(bytes, filename:, content_type: nil, **)
        { tempfile: StringIO.new(bytes), filename:, type: content_type }
      end
    end
  end
end
