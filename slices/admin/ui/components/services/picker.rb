# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Services
        class Picker < Component
          ID = "connect-service"
          CHEVRON = "fa-solid fa-chevron-right"

          prop :definitions, Blog::Types::Array.of(Blog::Types::Instance(::Services::Structs::Definition))

          def view_template
            Dialog(id: ID, title_id: "#{ID}-title", title: t(".title"), class: "modal", data: { dialog: true }) do
              @definitions.each { pick(it) }
              Hint { t(".hint") }
            end
            @definitions.select(&:oauth?).each { ConnectDialog(definition: it) }
          end

          private

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
        end
      end
    end
  end
end
