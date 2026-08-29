# frozen_string_literal: true

module Tasks
  module Contracts
    class TaskLinkContract < Blog::Contract
      params do
        required(:kind).value(Blog::Types::TaskLinkKind)
        required(:other_id).value(Blog::Types::Id)
      end
    end
  end
end
