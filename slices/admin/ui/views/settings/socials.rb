# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Settings
        class Socials < View
          LIVE_TABLES = (Components::People::List::LIVE_TABLES | Components::Webmentions::Settings::LIVE_TABLES).freeze

          prop :people, Blog::Types::Hash
          prop :tabs, Blog::Types::Hash
          prop :webmentions, Blog::Types::Hash

          def view_template
            content_for(:live_tables, LIVE_TABLES)
            SettingsHead(tab: :socials, title: t(".heading"), counts: @tabs)
            div(class: "settings-stack") do
              SettingsSection(id: Helpers::Socials::PEOPLE, title: t(".people")) do
                Components::People::List(**@people)
              end
              SettingsSection(id: Helpers::Socials::WEBMENTIONS, title: t(".webmentions")) do
                Components::Webmentions::Settings(**@webmentions)
              end
            end
          end
        end
      end
    end
  end
end
