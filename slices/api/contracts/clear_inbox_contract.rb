# frozen_string_literal: true

module API
  module Contracts
    class ClearInboxContract < Blog::Contract
      KINDS = %i[tasks messages webmentions].freeze

      params do
        KINDS.each { optional(it).value(Blog::Types::IdList) }
      end

      rule { base.failure(BLANK) if KINDS.all? { Array(values[it]).empty? } }
    end
  end
end
