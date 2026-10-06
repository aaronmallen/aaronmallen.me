# frozen_string_literal: true

module Blog
  module UI
    module Components
      class MainNav < Component
        PAGES = [
          %i[writing .pages.writing].freeze,
          %i[about .pages.about].freeze,
          %i[projects .pages.projects].freeze,
          %i[contact .pages.contact].freeze,
        ].freeze

        BRAND_ACCENT = "/"
        BRAND_SPLIT = " "
        LINKS_ID = "main-nav-links"

        prop :session, Blog::Types.Interface(:csrf_token, :signed_in?)

        def view_template
          header(class: "site-header") do
            a(class: "skip-link", href: "#main") { t(".skip_link") }

            nav(class: "main-nav", aria: { label: t(".label") }) do
              brand
              menu_toggle
              links
              settings
            end
          end
        end

        private

        def aria_current(href)
          "page" if current_page?(href)
        end

        def brand
          href = path(:root)
          owner = Blog::Owner.full_name

          a(class: "main-nav-brand", href:,
            aria: { label: t(".brand_label", owner:), current: aria_current(href) }) do
            brand_name(owner)
          end
        end

        def brand_name(owner)
          first, rest = owner.split(BRAND_SPLIT, 2)
          span { first }
          return unless rest

          span(class: "main-nav-brand-accent", aria: { hidden: "true" }) { BRAND_ACCENT }
          span { rest }
        end

        def current_page?(href) = request.path == href

        def links
          div(id: LINKS_ID, class: "main-nav-links") do
            PAGES.each { |(route, label_key)| nav_item(route:, label_key:) }
          end
        end

        def menu_toggle
          button(
            type: "button",
            class: "main-nav-toggle",
            aria: { controls: LINKS_ID, expanded: "false", label: t(".menu_label") },
            data: { disclosure: true },
          ) do
            Icon("fa-solid fa-bars main-nav-toggle-closed-icon")
            Icon("fa-solid fa-xmark main-nav-toggle-opened-icon")
          end
        end

        def nav_item(route:, label_key:)
          href = path(route)
          classes = ["main-nav-link", ("main-nav-link-current" if current_page?(href))]

          a(class: classes, href:, aria: { current: aria_current(href) }) { t(label_key) }
        end

        def settings
          div(class: "main-nav-settings") { SettingsMenu(session: @session) }
        end
      end
    end
  end
end
