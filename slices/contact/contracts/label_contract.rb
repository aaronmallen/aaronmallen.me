# frozen_string_literal: true

module Contact
  module Contracts
    class LabelContract < Blog::Contract
      params do
        required(:tags).value(Blog::Types::TagList)
      end

      rule(:tags).validate(:tag_slugs)
    end
  end
end
