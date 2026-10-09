# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Services
        class Picker < Component
          ID = "connect-service"
          CHEVRON = "fa-solid fa-chevron-right"
          GO = "fa-solid fa-arrow-up-right-from-square"

          prop :definitions, Blog::Types::Array.of(Blog::Types::Instance(::Services::Definition))

          def view_template
            Dialog(id: ID, title_id: "#{ID}-title", title: t(".title"), class: "modal", data: { dialog: true }) do
              @definitions.each { pick(it) }
              Hint { t(".hint") }
            end
            @definitions.each { connect(it) }
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
            end
          end

          def continue(definition)
            Form(action: path(:admin_connect_service, provider: definition.id)) do
              Button(variant: :pri, type: "submit", icon: GO) { t(".continue", name: definition.name) }
            end
          end

          def pick(definition)
            button(type: "button", class: "svc-pick", data: { dialog_open: "#{ID}-#{definition.id}" }) do
              Icon(definition.icon)
              span do
                span(class: "svc-line-name") { definition.name }
                span(class: "svc-line-note") { definition.powers.join(DOT) }
              end
              Icon(CHEVRON)
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
        end
      end
    end
  end
end
