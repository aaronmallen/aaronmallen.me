# frozen_string_literal: true

module Posts
  module Contracts
    class PostSeoContract < Blog::Contract
      params do
        optional(:canonical_url).value(Blog::Types::UrlOrBlank)
        optional(:og_image_url).value(Blog::Types::UrlOrBlank)
        optional(:og_title).value(Blog::Types::TrimmedText)
      end

      rule(:canonical_url).validate(:without_controls)
      rule(:og_image_url).validate(:without_controls)
      rule(:og_title).validate(:without_controls)
    end
  end
end
