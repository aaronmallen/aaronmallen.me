# frozen_string_literal: true

module Contact
  module Contracts
    class BulkContract < Blog::BulkContract
      params do
        required(:act).value(Blog::Types::MessageBulkAction)
      end
    end
  end
end
