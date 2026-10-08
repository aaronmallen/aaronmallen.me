# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Nav
        class ScreenTabs < Component
          include Navigated

          def view_template(&side)
            tabs = navigation&.tabs
            return if tabs.nil? || tabs.empty?

            div(class: "screen-tabs") do
              nav(class: "screen-tabs-list", aria: { label: t(".label") }) { tabs.each { tab(it) } }
              div(class: "screen-tabs-side", &side) if side
            end
          end

          private

          def count(section)
            return unless section.waiting?

            whitespace
            span(class: "screen-tab-count") { section.count.to_s }
            span(class: "sr-only") { t(".waiting") }
          end

          def tab(section)
            a(class: "screen-tab", href: section.path, aria: { current: ("page" if section.current) }) do
              plain t(section.label_key)
              count(section)
            end
          end
        end
      end
    end
  end
end
