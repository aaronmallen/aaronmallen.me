# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Services
        class Tile < Component
          prop :definition, Blog::Types::Instance(::Services::Structs::Definition)

          def view_template
            span(class: ["svc-tile", network], aria: { hidden: "true" }) { Icon(@definition.icon) }
          end

          private

          def network
            @definition.id if Blog::Constants::NETWORK_ICONS.key?(@definition.id)
          end
        end
      end
    end
  end
end
