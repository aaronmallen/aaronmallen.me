# frozen_string_literal: true

module Public
  module UI
    module Components
      class Footer < Component
        PROFILES = [
          %i[github fa-github .networks.github].freeze,
          %i[bluesky fa-bluesky .networks.bluesky].freeze,
          %i[mastodon fa-mastodon .networks.mastodon].freeze,
        ].freeze

        prop :year, Blog::Types::Integer

        def view_template
          footer(class: "site-footer") do
            div(class: "site-footer-content") do
              identity
              built_with
            end
          end
        end

        private

        def built_with
          span(class: "site-footer-group") do
            span { t(".built_with") }
            Icon("fa-solid fa-heart site-footer-heart", label: t(".heart_label"))
            built_with_link(href: "https://hanakai.org/hanami", name: "Hanami")
            span { t(".and") }
            built_with_link(href: "https://www.phlex.fun", name: "Phlex")
            span { t(".location") }
            span(aria: { hidden: "true" }) { t(".separator") }
            a(class: "site-footer-text-link", href: path(:privacy)) { t(".privacy") }
          end
        end

        def built_with_link(href:, name:)
          a(class: "site-footer-text-link", href:, target: "_blank", rel: "noopener") { name }
        end

        def copyright
          span(class: "site-footer-mark") do
            span(class: "site-footer-glasses", aria: { hidden: "true" })
            span do
              plain t(".copyright", year: @year)
              whitespace
              a(class: "site-footer-text-link p-name u-url u-uid", href: path(:root), rel: "me") do
                Hanami.app.settings.owner_name
              end
            end
          end
        end

        def identity
          span(class: "site-footer-group h-card") do
            copyright
            PROFILES.each { |(name, icon, label_key)| profile_link(name:, icon:, label_key:) }
          end
        end

        def profile_link(name:, icon:, label_key:)
          href = Hanami.app.settings.public_send(name)[:profile_url]
          return unless Blog::Types::Url.valid?(href)

          a(class: "site-footer-link", href:, rel: "me") do
            IconLabel(icon: ["fa-brands", icon]) { t(label_key) }
          end
        end
      end
    end
  end
end
