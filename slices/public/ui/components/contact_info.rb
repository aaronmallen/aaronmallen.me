# frozen_string_literal: true

module Public
  module UI
    module Components
      class ContactInfo < Component
        HANAKAI_URL = "https://hanakai.org"
        PROFILES = [
          %i[github fa-github .elsewhere.github].freeze,
          %i[mastodon fa-mastodon .elsewhere.mastodon].freeze,
          %i[bluesky fa-bluesky .elsewhere.bluesky].freeze,
        ].freeze

        def view_template
          dl(class: "ci") do
            row(".where.heading") { where }
            row(".work.heading") { work }
            row(".keep.heading") { keep }
            row(".elsewhere.heading") { elsewhere }
          end
        end

        private

        def elsewhere
          ul(class: "links") do
            PROFILES.each { |(network, icon, key)| profile(network, icon, key) }
          end
        end

        def keep
          span(class: "ci-v") { t(".keep.value") }
          span(class: "ci-s") { linked(".keep.detail", [".keep.privacy", path(:privacy)]) }
        end

        def linked(*parts)
          parts.each do |part|
            next plain(t(part)) if part.is_a?(String)

            key, href = part
            a(href:) { t(key) }
          end
        end

        def profile(network, icon, key)
          href = Hanami.app.settings.public_send(network)[:profile_url]
          return unless Blog::Types::Url.valid?(href)

          li do
            a(href:) { IconLabel(icon: ["fa-brands", icon]) { t(key) } }
          end
        end

        def row(heading_key, &)
          div(class: "ci-r") do
            dt(class: "kicker") { t(heading_key) }
            dd(&)
          end
        end

        def where
          span(class: "ci-v") { t(".where.value") }
          span(class: "ci-s") do
            span(data: { clock: Blog::TimeZone::NAME, clock_label: t(".where.clock") }) { t(".where.zone") }
          end
        end

        def work
          span(class: "ci-v") do
            linked(
              ".work.ruby",
              [".work.employer", path(:about)],
              ".work.hanami",
              [".work.hanakai", HANAKAI_URL],
              ".work.rust",
            )
          end
          span(class: "ci-s") { linked(".work.ask", [".work.projects", path(:projects)], ".work.welcome") }
        end
      end
    end
  end
end
