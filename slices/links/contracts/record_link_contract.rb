# frozen_string_literal: true

module Links
  module Contracts
    class RecordLinkContract < Blog::Contract
      params do
        required(:other_kind).value(Blog::Types::RecordKind)
        required(:other_id).value(Blog::Types::Id)
      end
    end
  end
end
