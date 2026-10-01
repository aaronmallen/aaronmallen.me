# frozen_string_literal: true

require "uri"

module Analytics
  module Ref
    KEY = "ref"
    MAX_SOURCE = 32
    SOURCE = /\A[a-z0-9]+(?:[._-][a-z0-9]+)*\z/
    TAGGED = /(?:\A|&)#{KEY}=/

    def self.source(value)
      found = value.to_s.strip.downcase
      found if found.length <= MAX_SOURCE && SOURCE.match?(found)
    end

    def self.tag(url, source)
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
