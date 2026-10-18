# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Settings
        class Services < View
          LIVE_TABLES = (Components::Services::List::LIVE_TABLES | Components::Clients::List::LIVE_TABLES).freeze

          prop :clients, Blog::Types::Hash
          prop :services, Blog::Types::Hash
          prop :tabs, Blog::Types::Hash
          prop :tokens, Blog::Types::Hash

          def view_template
            content_for(:live_tables, LIVE_TABLES)
            SettingsHead(tab: :services, title: t(".heading"), counts: @tabs)
            div(class: "settings-stack") do
              part(Helpers::ServiceTab::SERVICES, t(".services")) { Components::Services::List(**@services) }
              part(Helpers::ServiceTab::TOKENS, t(".tokens")) { Components::Tokens::List(**@tokens) }
              part(Helpers::ServiceTab::CLIENTS, t(".clients")) { Components::Clients::List(**@clients) }
            end
          end

          private

          def part(id, title, &) = SettingsSection(id:, title:, &)
        end
      end
    end
  end
end
