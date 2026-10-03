# frozen_string_literal: true

module Tasks
  module Contracts
    class BulkContract < Blog::Contract
      MAX_IDS = 100

      params do
        required(:act).value(Blog::Types::TaskBulkAction)
        required(:ids).value(Blog::Types::IdList, :filled?, max_size?: MAX_IDS)
      end
    end
  end
end
