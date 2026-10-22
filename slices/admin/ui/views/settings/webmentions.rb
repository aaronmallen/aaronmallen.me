# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Settings
        class Webmentions < View
          prop :tabs, Blog::Types::Hash
          prop :webmentions, Blog::Types::Hash

          def view_template
            content_for(:live_tables, Components::Webmentions::Settings::LIVE_TABLES)
            SettingsHead(tab: :webmentions, title: t(".heading"), counts: @tabs)
            div(class: "settings-stack") do
              SettingsSection(id: Helpers::WebmentionTab::WEBMENTIONS, title: t(".webmentions")) do
                Components::Webmentions::Settings(**@webmentions)
              end
            end
          end
        end
      end
    end
  end
end
