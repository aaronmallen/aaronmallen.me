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
            auto_approve_likes: ".auto_approve_likes",
            auto_approve_reposts: ".auto_approve_reposts",
            enable_on_new_posts: ".enable_on_new_posts",
            accept_bridgy: ".accept_bridgy",
          }.freeze
          HOSTS_ID = "webmention-single-author-hosts"

          prop :settings, Blog::Types::Instance(ROM::Struct)

          def view_template
            Card(title: t(".title"), id: "webmention-settings") do |card|
              card.side { span(class: "settings-count") { t(".endpoint", path: path(:webmention)) } }
              AutoForm(method: "post", action: path(:admin_update_webmention_settings)) do
                div(class: "form-stack") { fields }
                noscript { Button(type: "submit", small: true) { t(".save") } }
              end
            end
          end

          private

          def fields
            TOGGLES.each { |name, label_key| toggle(name, label_key) }
            hosts
          end

          def hosts
            Field(label: t(".single_author_hosts"), id: HOSTS_ID) do |control|
              Textarea(
                **control,
                name: "settings[single_author_hosts]",
                rows: 3,
                placeholder: t(".hosts_placeholder"),
                value: @settings.single_author_hosts.join("\n"),
              )
              Hint { t(".hosts_hint") }
            end
          end

          def toggle(name, label_key)
            Checkbox(switch: true, label: t(label_key), name: "settings[#{name}]", checked: @settings.public_send(name))
          end
        end
      end
    end
  end
end
