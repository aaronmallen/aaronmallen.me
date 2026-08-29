# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Social
        class Targets < Component
          prop :networks, Blog::Types::Array.of(Blog::Types::Instance(Structs::Network))
          prop :errors, Blog::Types::Hash, default: -> { Dry::Core::Constants::EMPTY_HASH }
          prop :name, Blog::Types::String, default: "social[targets][]"

          def view_template
            div(class: "compose-targets", role: "group", aria: { label: t(".label") }) do
              @networks.each { target(it) }
            end
            FieldError(field: :targets, errors: @errors)
          end

          private

          def checkbox(network)
            {
              class: "sr-only",
              type: "checkbox",
              name: @name,
              value: network.name,
              checked: network.selected,
              disabled: !network.configured,
              data: { social_target: network.name },
            }
          end

          def target(network)
            label(class: ["compose-target", network.name]) do
              input(**checkbox(network))
              i(class: "fa-solid fa-check compose-target-check", aria: { hidden: "true" })
              span { network.label }
            end
          end
        end
      end
    end
  end
end
