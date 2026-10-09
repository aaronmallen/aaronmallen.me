# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Services
        class Available < Component
          prop :definition, Blog::Types::Instance(::Services::Definition)

          def view_template
            ListItem(title: @definition.name, icon: @definition.icon, sub: @definition.powers.join(DOT))
          end
        end
      end
    end
  end
end
