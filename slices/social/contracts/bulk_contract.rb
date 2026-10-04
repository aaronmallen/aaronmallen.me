# frozen_string_literal: true

module Social
  module Contracts
    class BulkContract < Blog::BulkContract
      params do
        required(:act).value(Blog::Types::WebmentionVerdict)
      end
    end
  end
end
