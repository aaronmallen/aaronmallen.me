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

      rule(:name).validate(:without_controls, :visible)

      rule(:filters) do
        if !shaped?(value) then key.failure(FORMAT)
        elsif texts(value).any? { it.match?(CONTROLS) } then key.failure(CONTROL)
        end
      end

      private

      def group?(value) = value.is_a?(::Hash) && value.values.all? { text?(it) }

      def shaped?(filters) = filters.all? { |name, filter| text?(filter) || (name == GROUPED && group?(filter)) }

      def text?(value) = value.is_a?(::String)

      def texts(value) = value.is_a?(::Hash) ? value.flat_map { |name, item| [name, *texts(item)] } : [value]
    end
  end
end
