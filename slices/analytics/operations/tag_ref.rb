# frozen_string_literal: true

require "uri"

module Analytics
  module Operations
    class TagRef
      KEY = "ref"
      TAGGED = /(?:\A|&)#{KEY}=/

      def call(url, source)
        uri = URI.parse(url)
        return url if uri.query.to_s.match?(TAGGED)

        uri.path = "/" if uri.path.empty?
        uri.query = [uri.query, "#{KEY}=#{source}"].compact.join("&")
        uri.to_s
      rescue URI::Error
        url
      end
    end
  end
end
