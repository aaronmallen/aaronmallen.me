# frozen_string_literal: true

module Decisions
  module Contracts
    class ResolutionContract < ReasonContract
      params do
        required(:option_id).value(Blog::Types::Id)
      end
    end
  end
end
