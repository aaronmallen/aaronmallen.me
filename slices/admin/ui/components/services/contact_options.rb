# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Services
        class ContactOptions < Component
          prop :connection, Blog::Types::Instance(ROM::Struct)

          def view_template
            AutoForm(
              method: "post", action: path(:admin_contacts_service, id: @connection.id), data: { morph: true },
            ) do
              Checkbox(switch: true, label: t(".sync"), name: "sync_contacts", checked: @connection.sync_contacts)
              Checkbox(
                switch: true, label: t(".saves"), name: "saves_contacts", checked: @connection.saves_contacts,
                disabled: !@connection.sync_contacts,
              )
              noscript { Button(type: "submit", small: true) { t(".save") } }
            end
            Hint { t(".hint") }
          end
        end
      end
    end
  end
end
