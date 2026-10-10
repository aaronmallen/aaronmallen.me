# frozen_string_literal: true

module Public
  module UI
    module Views
      module Pages
        class Privacy < View
          SECTIONS = {
            cookies: { heading: ".cookies.heading", paragraphs: %w[.cookies.theme .cookies.admin] },
            address: { heading: ".address.heading", paragraphs: %w[.address.use .address.log] },
            hashes: {
              heading: ".hashes.heading",
              paragraphs: %w[.hashes.intro],
              items: %w[.hashes.items.day .hashes.items.month .hashes.items.post],
            },
            visits: {
              heading: ".visits.heading",
              paragraphs: %w[.visits.intro],
              items: %w[
                .visits.items.page .visits.items.referrer .visits.items.source .visits.items.country
                .visits.items.device .visits.items.reading .visits.items.clicks .visits.items.hashes
              ],
              closing: %w[.visits.read_through .visits.script],
            },
            feeds: { heading: ".feeds.heading", paragraphs: %w[.feeds.body] },
            retention: {
              heading: ".retention.heading",
              items: %w[
                .retention.items.events .retention.items.feeds .retention.items.posts .retention.items.totals
              ],
            },
            messages: { heading: ".messages.heading", paragraphs: %w[.messages.body] },
            errors: { heading: ".errors.heading", paragraphs: %w[.errors.body] },
            basis: { heading: ".basis.heading", paragraphs: %w[.basis.body] },
          }.freeze

          def view_template
            content_for(:title, t(".title"))

            page_head
            div(class: "prose") do
              SECTIONS.each_value { topic(**it) }
              requests
            end
          end

          private

          def paragraphs(keys) = keys.each { |key| p { t(key) } }

          def requests
            h2 { t(".requests.heading") }
            linked_line(".requests.body", path(:contact), ".requests.link", ".requests.closing")
          end

          def topic(heading:, paragraphs: [], items: [], closing: [])
            h2 { t(heading) }
            paragraphs(paragraphs)
            ul { items.each { |item| li { t(item) } } } unless items.empty?
            paragraphs(closing)
          end
        end
      end
    end
  end
end
