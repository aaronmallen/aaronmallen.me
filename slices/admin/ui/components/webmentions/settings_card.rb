# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Webmentions
        class SettingsCard < Component
          TOGGLES = {
            receive: ".receive",
            send_on_publish: ".send_on_publish",
            auto_approve_known_authors: ".auto_approve",
            enable_on_new_posts: ".enable_on_new_posts",
            accept_bridgy: ".accept_bridgy",
          }.freeze

          prop :settings, Blog::Types::Instance(ROM::Struct)
          prop :filter, Blog::Types::String

          def view_template
            Card(title: t(".title")) do
              Form(action: path(:admin_update_webmention_settings), data: { autosubmit: "" }) do
                input(type: "hidden", name: "status", value: @filter)
                div(class: "form-stack") { TOGGLES.each { |name, label_key| toggle(name, label_key) } }
                noscript { Button(type: "submit", small: true) { t(".save") } }
              end
              Hint { t(".endpoint", path: path(:webmention)) }
            end
          end

          private

          def toggle(name, label_key)
            Toggle(label: t(label_key), name: "settings[#{name}]", checked: @settings.public_send(name))
          end
        end
      end
    end
  end
end
