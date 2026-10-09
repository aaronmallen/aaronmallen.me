# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Services
        class Available < Component
          prop :definition, Blog::Types::Instance(::Services::Definition)
          prop :connectable, Blog::Types::Bool

          def view_template
            ListItem(title: @definition.name, icon: @definition.icon, sub: @definition.powers.join(DOT)) do
              next unless @connectable

              Button(small: true, variant: :pri, href: path(:admin_services, connect: @definition.id)) { t(".connect") }
            end
          end
        end
      end
    end
  end
end
