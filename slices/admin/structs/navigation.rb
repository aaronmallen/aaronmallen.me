# frozen_string_literal: true

module Admin
  module Structs
    Navigation = Data.define(:sections, :actions, :inbox) do
      def current = sections.find(&:current)

      def inbox_count = inbox.values.sum

      def pills = sections.group_by(&:group).except(:settings)

      def tabs
        found = pills.fetch(current&.group, [])
        found.size > 1 ? found : []
      end
    end
  end
end
