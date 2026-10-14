# frozen_string_literal: true

module Performance
  module Contracts
    class PageTimingContract < Blog::Contract
      MAX_MS = 10 * Blog::Helpers::Figures::MINUTE * 1000
      OUT_OF_ORDER = "out of order"

      json do
        required(:ttfb).value(:integer, gteq?: 0, lteq?: MAX_MS)
        required(:dom_content_loaded).value(:integer, gteq?: 0, lteq?: MAX_MS)
        required(:load).value(:integer, gteq?: 0, lteq?: MAX_MS)
        optional(:lcp).value(:integer, gteq?: 0, lteq?: MAX_MS)
      end

      rule(:dom_content_loaded, :ttfb) do
        key.failure(OUT_OF_ORDER) if values[:dom_content_loaded] < values[:ttfb]
      end

      rule(:load, :dom_content_loaded) do
        key.failure(OUT_OF_ORDER) if values[:load] < values[:dom_content_loaded]
      end
    end
  end
end
