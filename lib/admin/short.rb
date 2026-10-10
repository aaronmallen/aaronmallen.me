# frozen_string_literal: true

module Admin
  module Short
    def self.sha(sha) = sha.to_s[0, 7]

    def self.title(text) = Blog::Helpers::Truncation.cut(text, keep: 80)
  end
end
