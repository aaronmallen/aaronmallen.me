# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Settings
        class Tagging < View
          LIVE_TABLES = (Components::Tags::List::LIVE_TABLES | Components::TaskRules::List::LIVE_TABLES).freeze

          prop :rules, Blog::Types::Hash
          prop :tags, Blog::Types::Hash

          def view_template
            content_for(:live_tables, LIVE_TABLES)
            SettingsHead(tab: :tagging, title: t(".heading"))
            div(class: "settings-stack") do
              SettingsSection(id: Helpers::TagList::TAGS, title: t(".tags")) { Components::Tags::List(**@tags) }
              SettingsSection(id: Helpers::TagList::RULES, title: t(".rules")) { Components::TaskRules::List(**@rules) }
            end
          end
        end
      end
    end
  end
end
