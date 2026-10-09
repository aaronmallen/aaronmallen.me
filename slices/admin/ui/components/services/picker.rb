# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Services
        class Picker < Component
          ID = "connect-service"
          CHEVRON = "fa-solid fa-chevron-right"
          GO = "fa-solid fa-arrow-up-right-from-square"
          LINK_ICON = "fa-solid fa-link"
          MASTODON = "mastodon"
          SERVER_FIELD = {
            autocapitalize: "none", autocomplete: "off", name: "server", placeholder: "mastodon.social", required: true,
            spellcheck: "false",
          }.freeze

          prop :definitions, Blog::Types::Array.of(Blog::Types::Instance(::Services::Definition))

          def view_template
            Dialog(id: ID, title_id: "#{ID}-title", title: t(".title"), class: "modal", data: { dialog: true }) do
              @definitions.each { pick(it) }
              Hint { t(".hint") }
            end
            @definitions.select(&:oauth?).each { connect(it) }
          end

          private

          def connect(definition)
            id = "#{ID}-#{definition.id}"
            title = t(".connect", name: definition.name)
            Dialog(id:, title_id: "#{id}-title", title:, class: "modal", data: { dialog: true }) do
              p(class: "settings-aside") { t(".away", name: definition.name) }
              p(class: "svc-group-label") { t(".asks") }
              definition.scopes.each { scope(it) }
              Hint { t(".revoke", name: definition.name) }
              continue(definition)
              token(definition) if definition.credentials?
            end
          end

          def continue(definition)
            Form(action: path(:admin_connect_service, provider: definition.id)) do
              server if definition.id == MASTODON
              Button(variant: :pri, type: "submit", icon: GO) { t(".continue", name: definition.name) }
            end
          end

          def line(definition)
            Icon(definition.icon)
            span do
              span(class: "svc-line-name") { definition.name }
              span(class: "svc-line-note") { definition.powers.join(DOT) }
            end
            Icon(CHEVRON)
          end

          def pick(definition)
            if definition.oauth?
              button(type: "button", class: "svc-pick", data: { dialog_open: "#{ID}-#{definition.id}" }) do
                line(definition)
              end
            else
              a(href: path(:admin_services, connect: definition.id), class: "svc-pick") { line(definition) }
            end
          end

          def scope(scope)
            label(class: "choice") do
              input(class: "check", type: "checkbox", checked: true, disabled: true)
              span(class: "svc-scope") do
                span(class: "svc-line-name") { scope[:label] }
                span(class: "svc-line-note") { t(".required", why: scope[:why]) }
              end
            end
          end

          def server
            Field(label: t(".server"), id: "#{ID}-server") do |control|
              Input(**control, **SERVER_FIELD)
            end
          end

          def token(definition)
            Form(action: path(:admin_create_service, provider: definition.id), class: "svc-connect") do
              p(class: "svc-group-label") { t(".or_token") }
              definition.fields.each { token_field(definition, it) }
              Hint { t(".token_hint") }
              Button(variant: :pri, type: "submit", icon: LINK_ICON) { t(".connect", name: definition.name) }
            end
          end

          def token_field(definition, name)
            Field(label: t(".token"), id: "#{ID}-#{definition.id}-#{name}") do |control|
              Input(**control, type: "password", autocomplete: "off", name: "connection[#{name}]", required: true)
            end
          end
        end
      end
    end
  end
end
