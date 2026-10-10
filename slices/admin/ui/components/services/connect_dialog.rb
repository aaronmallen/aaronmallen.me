# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Services
        class ConnectDialog < Component
          GO = "fa-solid fa-arrow-up-right-from-square"
          SERVER_FIELD = {
            autocapitalize: "none", autocomplete: "off", name: "server", placeholder: "mastodon.social", required: true,
            spellcheck: "false",
          }.freeze

          prop :definition, Blog::Types::Instance(::Services::Structs::Definition)

          def view_template
            Dialog(id:, title_id: "#{id}-title", title: t(".connect", name:), class: "modal", data: { dialog: true }) do
              p(class: "settings-aside") { t(".away", name:) }
              p(class: "svc-group-label") { t(".asks") }
              @definition.scopes.each { scope(it) }
              Hint { t(".revoke", name:) }
              continue
              token if @definition.credentials?
            end
          end

          private

          def continue
            Form(action: path(:admin_connect_service, provider: @definition.id)) do
              server if @definition.host
              Button(variant: :pri, type: "submit", icon: GO) { t(".continue", name:) }
            end
          end

          def id = "#{Picker::ID}-#{@definition.id}"

          def name = @definition.name

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
            Field(label: t(".server"), id: "#{Picker::ID}-server") do |control|
              Input(**control, **SERVER_FIELD)
            end
          end

          def token
            TokenForm(definition: @definition) do
              p(class: "svc-group-label") { t(".or_token") }
              @definition.fields.each { token_field(it) }
              Hint { t(".token_hint") }
            end
          end

          def token_field(field)
            Field(label: t(".token"), id: "#{id}-#{field}") do |control|
              Input(**control, type: "password", autocomplete: "off", name: "connection[#{field}]", required: true)
            end
          end
        end
      end
    end
  end
end
