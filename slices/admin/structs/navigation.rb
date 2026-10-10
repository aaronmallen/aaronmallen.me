# frozen_string_literal: true

module Admin
  module Structs
    Navigation = Data.define(:sections, :actions) do
      def current = sections.find(&:current)

      def pills = sections.group_by(&:group).except(:settings)

      def settings = sections.select { it.group == :settings }

      def tabs
        group = current&.group
        found = sections.select { it.group == group }
        found.size > 1 ? found : []
      end
    end
  end
end
