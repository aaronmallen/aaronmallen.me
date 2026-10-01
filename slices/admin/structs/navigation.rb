# frozen_string_literal: true

module Admin
  module Structs
    Navigation = Data.define(:sections) do
      def alert? = sections.any?(&:waiting?)

      def current = sections.find(&:current)
    end
  end
end
