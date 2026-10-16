# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Services
        class Row < Component
          prop :row, Blog::Types::Instance(Structs::ServiceRow)
          prop :selected, Blog::Types::Bool

          def view_template
            div(class: "li svc", data: { key_row: true, menu: path(:admin_service_menu, key: @row.key) }) do
              div(class: "svc-start") do
                Tile(definition: @row.definition)
                div(class: "li-main") do
                  a(class: "li-title", href:, data: { key_open: true }, **link) { @row.definition.name }
                  p(class: "li-sub") { sub }
                end
              end
              StatusPill(status: @row.status)
            end
          end

          private

          def href = @selected ? path(:admin_services) : path(:admin_services, selected: @row.key)

          def link = @selected ? { aria: { current: "true" } } : Blog::Constants::EMPTY_HASH

          def sub
            used_at = @row.connection&.last_used_at

            Dotted do |line|
              line.part { span(class: "svc-account") { @row.account } if @row.account }
              line.part { Stamped(text: t(".used", time: Stamped::MARK), at: used_at) if used_at }
            end
          end
        end
      end
    end
  end
end
