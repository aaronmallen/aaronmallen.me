# frozen_string_literal: true

module Notes
  module Contracts
    class NoteFolderContract < Blog::Contract
      DESCRIPTION_LIMIT = 1000
      NAME_LIMIT = 100

      params do
        optional(:name).filled(Blog::Types::TrimmedText, max_size?: NAME_LIMIT)
        optional(:description).value(Blog::Types::Normalized::Lines, max_size?: DESCRIPTION_LIMIT)
        optional(:parent_id).maybe(Blog::Types::Id)
      end

      rule(:name).validate(:without_controls, :visible)
      rule(:description).validate(:without_controls)
    end
  end
end
