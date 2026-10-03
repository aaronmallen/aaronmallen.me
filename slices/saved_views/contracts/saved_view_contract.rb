# frozen_string_literal: true

module SavedViews
  module Contracts
    class SavedViewContract < Blog::Contract
      GROUPED = "types"
      MAX_NAME = 100

      params do
        required(:name).value(Blog::Types::TrimmedText, :filled?, max_size?: MAX_NAME)
        required(:screen).filled(Blog::Types::SavedViewScreen)
        required(:filters).value(:hash)
      end

      rule(:name).validate(:without_controls)

      rule(:filters) do
        key.failure(FORMAT) unless value.all? { |name, filter| text?(filter) || (name == GROUPED && group?(filter)) }
      end

      private

      def group?(value) = value.is_a?(::Hash) && value.values.all? { text?(it) }

      def text?(value) = value.is_a?(::String)
    end
  end
end
