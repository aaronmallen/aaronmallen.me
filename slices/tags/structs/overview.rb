# frozen_string_literal: true

module Tags
  module Structs
    Overview = Data.define(:name, :tags, :counts, :pages) do
      def count = counts.values.sum

      def empty? = pages.values.all? { it.rows.empty? }

      def tag(scope) = tags.find { it.scope == scope }
    end
  end
end
