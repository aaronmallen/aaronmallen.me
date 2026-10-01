# frozen_string_literal: true

module Media
  module Contracts
    class PhotoContract < Blog::Contract
      LARGE = "large"
      MAX_BYTES = 20 * 1024 * 1024
      TYPE = "type"

      schema do
        required(:photo).filled
      end

      rule(:photo) do
        if value.size > MAX_BYTES
          key.failure(LARGE)
        elsif PhotoType.detect(value).nil?
          key.failure(TYPE)
        end
      end
    end
  end
end
