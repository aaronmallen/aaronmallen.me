# frozen_string_literal: true

module Public
  module UI
    module Components
      class Footer < Component
        PROFILES = {
          github: %w[fa-github .networks.github].freeze,
          bluesky: %w[fa-bluesky .networks.bluesky].freeze,
          mastodon: %w[fa-mastodon .networks.mastodon].freeze,
        }.freeze

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
            Profiles.call(*PROFILES.keys).each { |network, href| profile_link(href, *PROFILES.fetch(network)) }
          end
        end

        def profile_link(href, icon, label_key)
          a(class: "site-footer-link", href:, rel: "me") do
            IconLabel(icon: ["fa-brands", icon]) { t(label_key) }
          end
        end
      end
    end
  end
end
