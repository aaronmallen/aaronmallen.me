# frozen_string_literal: true

module Tasks
  module Contracts
    class ColumnContract < Blog::BulkContract
      params do
        required(:to).value(Blog::Types::TaskColumn)
      end
    end
  end
end
