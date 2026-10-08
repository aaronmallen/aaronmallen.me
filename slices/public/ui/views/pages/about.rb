# frozen_string_literal: true

module Public
  module UI
    module Views
      module Pages
        class About < View
          HANAKAI_URL = "https://hanakai.org"
          HOBBIES = [
            %w[.hobbies.magic.name .hobbies.magic.body].freeze,
            %w[.hobbies.dnd.name .hobbies.dnd.body].freeze,
            %w[.hobbies.games.name .hobbies.games.body].freeze,
          ].freeze
          PROFILES = [
            %i[github fa-github .cta.links.github].freeze,
            %i[mastodon fa-mastodon .cta.links.mastodon].freeze,
            %i[bluesky fa-bluesky .cta.links.bluesky].freeze,
          ].freeze

          prop :work_entries, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))

          def view_template
            content_for(:title, t(".title"))

            section(class: "about") do
              span(class: "kicker") { t(".kicker") }
              h1(class: "page-title") { t(".heading") }
              p(class: "lede") { t(".lede") }
              prose
              career
              cta
            end
          end

          private

          def away
            h2 { t(".prose.away") }
            ul do
              HOBBIES.each do |(name, body)|
                li do
                  strong { t(name) }
                  plain(t(".hobbies.separator"))
                  plain(t(body))
                end
              end
            end
          end

          def career
            return if @work_entries.empty?

            h2(class: "work-title") { t(".career") }
            div(class: "rows") { @work_entries.each { WorkRow(entry: it) } }
          end

          def cta
            div(class: "cta") do
              h2 { t(".cta.heading") }
              p { t(".cta.body") }
              ul(class: "links") do
                li { link(path(:contact), "fa-solid fa-envelope", t(".cta.links.contact")) }
                PROFILES.each { |(network, icon, key)| profile(network, icon, key) }
              end
            end
          end

          def link(href, icon, label)
            a(href:) do
              IconLabel(icon:) { label }
            end
          end

          def open_source
            h2 { t(".prose.open_source.heading") }
            paragraph_with_link(".prose.open_source.rust", path(:projects), ".prose.open_source.projects_link")
            paragraph_with_link(".prose.open_source.ruby", HANAKAI_URL, ".prose.open_source.hanakai_link")
          end

          def paragraph_with_link(lead, href, label)
            p do
              plain(t(lead))
              whitespace
              a(href:) { t(label) }
              plain(t(".prose.open_source.closing"))
            end
          end

          def profile(network, icon, key)
            href = Hanami.app.settings.public_send(network)[:profile_url]
            return unless Blog::Types::Url.valid?(href)

            li { link(href, "fa-brands #{icon}", t(key)) }
          end

          def prose
            div(class: "post-body") do
              p { t(".prose.work") }
              p { t(".prose.structure") }
              open_source
              blockquote { p { t(".prose.quote") } }
              away
            end
          end
        end
      end
    end
  end
end
