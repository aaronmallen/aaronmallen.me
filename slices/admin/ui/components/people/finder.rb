# frozen_string_literal: true

module Admin
  module UI
    module Components
      module People
        class Finder < Component
          ICONS = {
            Blog::Types::NetworkName["bluesky"] => "fa-brands fa-bluesky",
            Blog::Types::NetworkName["mastodon"] => "fa-brands fa-mastodon",
          }.freeze
          ID = "person-finder"
          INPUT_ID = "#{ID}-q".freeze
          TITLE_ID = "#{ID}-title".freeze

          prop :networks, Blog::Types::Array.of(Blog::Types::NetworkName)

          def view_template
            aside(
              id: ID, class: "card settings-side person-finder", hidden: true, aria: { labelledby: TITLE_ID },
              data: { person_finder: "", person_finder_failed: t(".failed") },
            ) do
              header(class: "card-head") do
                h2(id: TITLE_ID, class: "card-title") { t(".title") }
                toggle
              end
              search_form
              div(class: "person-finder-results", aria: { live: "polite" }, data: { person_finder_results: "" })
            end
          end

          private

          def first = @networks.first

          def network_label(network) = t(Structs::Network::LABELS.fetch(network))

          def option(network)
            label(class: "seg-option #{network}") do
              input(
                class: "sr-only", type: "radio", name: "network", value: network, checked: network == first,
                data: {
                  person_finder_url: path(:admin_search_people, network:),
                  person_finder_label: t(".label", network: network_label(network)),
                  person_finder_placeholder: t(".placeholder", network: network_label(network)),
                },
              )
              span do
                Icon(ICONS.fetch(network))
                plain network_label(network)
              end
            end
          end

          def search_form
            form(class: "person-finder-form", role: "search", data: { person_finder_form: "" }) do
              label(class: "sr-only", for: INPUT_ID, data: { person_finder_label: "" }) do
                t(".label", network: network_label(first))
              end
              Input(
                type: "search", id: INPUT_ID, name: "q", autocomplete: "off",
                placeholder: t(".placeholder", network: network_label(first)), data: { person_finder_input: "" },
              )
              Button(type: "submit", small: true) { t(".search") }
            end
          end

          def toggle
            div(class: "seg", role: "radiogroup", aria: { label: t(".network") }) { @networks.each { option(it) } }
          end
        end
      end
    end
  end
end
