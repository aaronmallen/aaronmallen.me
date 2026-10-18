# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Nav
        class Switcher < Component
          ID = "nav-switcher"

          prop :navigation, Blog::Types::Instance(Structs::Navigation)

          def view_template
            label = t(".label", current: named)

            button(type: "button", class: "switcher", popovertarget: ID, aria: { label: }) do
              span(class: "switcher-group") { group }
              span(class: "switcher-screen") { screen } if screen
              span(class: "pill-nav-dot") if waiting?
              Icon("fa-solid fa-chevron-down switcher-chevron")
            end

            nav(id: ID, class: "switcher-panel", popover: "auto", aria: { label: t(".panel") }) do
              @navigation.pills.each { |name, sections| column(name, sections) }
            end
          end

          private

          def column(name, sections)
            div(class: "switcher-column") do
              heading(name, sections) if sections.size > 1
              sections.each { row(it) }
            end
          end

          def current = @navigation.current

          def group = current ? t(current.group_key) : t(".menu")

          def heading(name, sections)
            p(class: "switcher-heading") do
              plain t(sections.first.group_key)
              next unless name == TopBar::INBOX && sections.any?(&:waiting?)

              span(class: "pill-nav-dot", aria: { hidden: "true" })
              span(class: "sr-only") { t(".waiting") }
            end
          end

          def named = [group, screen].compact.join(", ")

          def row(section)
            a(class: "switcher-row", href: section.path, aria: { current: ("page" if section.current) }) do
              Icon(["fa-solid", section.icon, "switcher-icon"])
              plain t(section.label_key)
            end
          end

          def screen
            return unless current

            label = t(current.label_key)
            label unless label.casecmp?(group)
          end

          def waiting? = @navigation.pills.fetch(TopBar::INBOX, []).any?(&:waiting?)
        end
      end
    end
  end
end
