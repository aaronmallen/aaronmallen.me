# frozen_string_literal: true

module Posts
  module PostSlug
    def self.derive(slug:, title:)
      given = Blog::Types::TrimmedText[slug]

      given.empty? ? from_title(title) : given
    end

    def self.from_title(title) = Blog::Types::Normalized::Slug.call(title) { Dry::Core::Constants::EMPTY_STRING }
  end
end
