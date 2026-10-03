# frozen_string_literal: true

module Admin
  module Structs
    Action = Data.define(:name, :icon, :path, :dialog) do
      def id = "command-palette-#{name.to_s.tr('_', '-')}"

      def label_key = "ui.components.nav.actions.#{name}.label"

      def text_key = "ui.components.nav.actions.#{name}.text"
    end
  end
end
