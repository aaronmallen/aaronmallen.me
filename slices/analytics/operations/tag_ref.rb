# frozen_string_literal: true

require "uri"

module Analytics
  module Operations
    class TagRef
      TAGGED = /(?:\A|&)#{Blog::Constants::REF_KEY}=/

      def call(url, source)
        uri = URI.parse(url)
        return url if uri.query.to_s.match?(TAGGED)

        uri.path = "/" if uri.path.empty?
        uri.query = [uri.query, "#{Blog::Constants::REF_KEY}=#{source}"].compact.join("&")
        uri.to_s
      rescue URI::Error
        url
      end
    end
  end
end
