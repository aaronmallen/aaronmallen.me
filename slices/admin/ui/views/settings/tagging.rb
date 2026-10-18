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
              part(Helpers::TagList::TAGS, t(".tags")) { Components::Tags::List(**@tags) }
              part(Helpers::TagList::RULES, t(".rules")) { Components::TaskRules::List(**@rules) }
            end
          end

          private

          def part(id, title)
            heading = "#{id}-heading"

            section(id:, class: "settings-section", aria: { labelledby: heading }) do
              h2(id: heading, class: "settings-section-heading") { title }
              yield
            end
          end
        end
      end
    end
  end
end
