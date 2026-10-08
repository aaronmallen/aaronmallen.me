# frozen_string_literal: true

module Admin
  module Structs
    Action = Data.define(:name, :icon, :path, :dialog, :post, :needs, :from, :key, :click) do
      def initialize(name:, icon:, path:, dialog: nil, post: false, needs: nil, from: nil, key: nil, click: nil)
        super
      end

      def id = "command-palette-#{name.to_s.tr('_', '-')}"

      def label_key = "ui.components.nav.actions.#{name}.label"

      def text_key = "ui.components.nav.actions.#{name}.text"
    end
  end
end
