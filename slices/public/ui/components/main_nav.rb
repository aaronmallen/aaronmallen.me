# frozen_string_literal: true

module Public
  module UI
    module Components
      class MainNav < Component
        PAGES = [
          %i[writing .pages.writing].freeze,
          %i[about .pages.about].freeze,
          %i[projects .pages.projects].freeze,
          %i[contact .pages.contact].freeze,
        ].freeze

        prop :session, Blog::Types.Interface(:csrf_token, :signed_in?)

        def view_template
          header(class: "site-header") do
            a(class: "skip-link", href: "#main") { t(".skip_link") }
            Wordmark(placement: "main-nav-brand")
            nav(class: "main-nav", aria: { label: t(".label") }) do
              PAGES.each { |(route, label_key)| nav_item(route:, label_key:) }
            end
            div(class: "main-nav-settings") { @session.signed_in? ? SettingsMenu(session: @session) : theme_toggle }
          end
        end

        private

        def nav_item(route:, label_key:)
          href = path(route)

          a(class: "main-nav-link", href:, aria: { current: ("page" if request.path == href) }) { t(label_key) }
        end

        def theme_toggle
          button(
            type: "button",
            class: "settings-menu-toggle",
            aria: { label: t(".theme_toggle_label") },
            data: { theme_toggle: true },
          ) do
            Icon("fa-solid fa-sun theme-toggle-light")
            Icon("fa-solid fa-moon theme-toggle-dark")
          end
        end
      end
    end
  end
end
