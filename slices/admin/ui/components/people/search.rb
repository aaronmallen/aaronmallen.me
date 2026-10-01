# frozen_string_literal: true

module Admin
  module UI
    module Components
      module People
        class Search < Component
          prop :network, Blog::Types::NetworkName

          def self.input_id(network) = "person-#{network}-search"

          def self.list_id(network) = "person-#{network}-results"

          def view_template
            div(class: "person-search", hidden: true, data:) do
              label(class: "sr-only", for: input_id) { t(".label", network: network_label) }
              box
              div(
                id: list_id, class: "person-search-results", role: "listbox", hidden: true,
                aria: { label: t(".results_label", network: network_label) }, data: { person_search_results: "" },
              )
              p(class: "sr-only", role: "status", data: { person_search_status: "" })
            end
          end

          private

          def box
            div(class: "person-search-box") do
              i(class: "fa-solid fa-magnifying-glass", aria: { hidden: "true" })
              Input(
                type: "search", id: input_id, autocomplete: "off", role: "combobox",
                placeholder: t(".placeholder", network: network_label),
                aria: { autocomplete: "list", controls: list_id, expanded: "false" },
                data: { person_search_input: "" },
              )
            end
          end

          def data
            {
              person_search: @network,
              person_search_url: path(:admin_search_people, network: @network),
              person_search_failed: t("ui.components.people.search_results.failed", network: network_label),
              person_search_results_one: t(".results.one"),
              person_search_results_other: t(".results.other"),
            }
          end

          def input_id = self.class.input_id(@network)

          def list_id = self.class.list_id(@network)

          def network_label = t(Structs::Network::LABELS.fetch(@network))
        end
      end
    end
  end
end
