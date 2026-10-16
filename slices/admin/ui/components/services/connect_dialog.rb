# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Services
        class ConnectDialog < Component
          SERVER_FIELD = {
            autocapitalize: "none", autocomplete: "off", name: "server", placeholder: "mastodon.social", required: true,
            spellcheck: "false",
          }.freeze
          SHELL = { class: "modal" }.freeze

          def self.id_for(definition, connection = nil) = [Picker::ID, definition.id, connection&.id].compact.join("-")

          prop :definition, Blog::Types::Instance(::Services::Structs::Definition)
          prop :connection, Blog::Types::Instance(::Services::Structs::ServiceConnection).optional, default: nil

          def view_template
            Dialog(id:, title:, **SHELL) do |dialog|
              head
              continue
              asks
              token if @definition.credentials?
              dialog.foot { foot }
            end
          end

          private

          def asks
            p(class: "svc-group-label") { t(".asks") }
            @definition.scopes.each { scope(it) }
            Hint { t(".revoke", name:) }
          end

          def continue
            Form(id: form_id, action: path(:admin_connect_service, provider: @definition.id)) do
              server if @definition.host
              input(type: "hidden", name: "connection", value: @connection.id) if @connection
            end
          end

          def foot
            Button(small: true, variant: :gh, data: { dialog_close: true }) do
              t("ui.components.edit_note_dialog.cancel")
            end
            Button(small: true, variant: :pri, type: "submit", form: form_id, icon: :outbound) { t(".continue", name:) }
          end

          def form_id = "#{id}-form"

          def head
            div(class: "svc-intro") do
              Tile(definition: @definition)
              div do
                p(class: "svc-intro-title") { name }
                Hint { t(".away", name:) }
              end
            end
          end

          def id = self.class.id_for(@definition, @connection)

          def name = @definition.name

          def scope(scope)
            optional = scope[:optional]
            label(class: "svc-scope") do
              input(class: "check", type: "checkbox", name: "scopes[]", value: scope[:id], form: form_id,
                    checked: ticked?(scope), disabled: !optional)
              span do
                span(class: "svc-scope-name") { scope[:label] }
                span(class: "svc-scope-why") { optional ? scope[:why] : t(".required", why: scope[:why]) }
              end
            end
          end

          def server
            Field(label: t(".server"), id: "#{Picker::ID}-server") do |control|
              Input(**control, **SERVER_FIELD)
            end
          end

          def ticked?(scope) = !scope[:optional] || @connection.nil? || @definition.granted?(scope, @connection.scopes)

          def title = @connection ? t(".change", account: @connection.label) : t(".connect", name:)

          def token
            TokenForm(definition: @definition) do
              p(class: "svc-group-label") { t(".or_token") }
              @definition.fields.each { token_field(it) }
              Hint { t("ui.components.services.connect.token_hint") }
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
