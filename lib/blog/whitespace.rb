# frozen_string_literal: true

module Blog
  module Whitespace
    def self.squish(text) = text.to_s.gsub(/\s+/, " ").strip
  end
end
