# frozen_string_literal: true

module Admin
  module Structs
    Section = Data.define(:name, :group, :icon, :path, :count, :current) do
      def group_key = "ui.components.nav.groups.#{group}"

      def label_key = "ui.components.nav.sections.#{name}"

      def waiting? = count.positive?
    end
  end
end
