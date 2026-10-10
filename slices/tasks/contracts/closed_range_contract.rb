# frozen_string_literal: true

module Tasks
  module Contracts
    class ClosedRangeContract < Blog::Contract
      params do
        required(:from).value(:date)
        required(:to).value(:date)
      end

      rule(:from, :to) { key(:to).failure(FORMAT) if values[:to] < values[:from] }
    end
  end
end
