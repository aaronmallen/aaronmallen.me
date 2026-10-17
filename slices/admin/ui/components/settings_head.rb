# frozen_string_literal: true

module Admin
  module UI
    module Components
      class SettingsHead < Component
        TABS = { security: :admin_security }.freeze
        LABELS = TABS.keys.to_h { [it, ".tabs.#{it}"] }.freeze

        prop :tab, Blog::Types::Symbol.enum(*TABS.keys).optional, default: nil
        prop :title, Blog::Types::String

        def view_template(&)
          content_for(:title, @title)
          PageHead(title: t(".heading"), sub: t(".lede"), &)
          tabs if @tab
        end

        private

        def tabs
          div(class: "screen-tabs") do
            nav(class: "screen-tabs-list", aria: { label: t(".tabs.label") }) do
              TABS.each do |name, route|
                a(class: "screen-tab", href: path(route), aria: { current: ("page" if name == @tab) }) do
                  t(LABELS.fetch(name))
                end
              end
            end
          end
        end
      end
    end
  end
end
