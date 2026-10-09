# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Nav
        class TopBar < Component
          INBOX = :inbox
          SEARCH_KEY = "/"
          SHORTCUT = "⌘K"

          prop :navigation, Blog::Types::Instance(Structs::Navigation).optional
          prop :session, Blog::Types.Interface(:csrf_token, :signed_in?)

          def view_template
            header(class: "top-bar") do
              a(class: "top-bar-skip", href: "#main") { t(".skip_link") }
              Wordmark(placement: "top-bar-wordmark")
              @navigation ? signed_in : SettingsMenu(session: @session)
            end
          end

          private

          def pill(group, sections)
            current = sections.any?(&:current)

            a(class: "pill-nav-link", href: sections.first.path, aria: { current: ("page" if current) }) do
              plain t(sections.first.group_key)
              waiting_dot if group == INBOX && sections.any?(&:waiting?)
            end
          end

          def pills
            nav(class: "pill-nav", aria: { label: t(".label") }) do
              @navigation.pills.each { |group, sections| pill(group, sections) }
            end
          end

          def search
            label = t(".search")

            button(
              type: "button", class: "top-bar-search", aria: { label: },
              data: { palette_open: true, key: SEARCH_KEY, key_label: t(".palette") },
            ) do
              Icon("fa-solid fa-magnifying-glass")
              span(class: "top-bar-search-label", aria: { hidden: "true" }) { t(".search_hint") }
              span(class: "top-bar-search-key", aria: { hidden: "true" }) { SHORTCUT }
            end
          end

          def signed_in
            pills
            search
            AvatarMenu(settings: @navigation.settings)
          end

          def waiting_dot
            span(class: "pill-nav-dot", aria: { hidden: "true" })
            span(class: "sr-only") { t(".waiting") }
          end
        end
      end
    end
  end
end
