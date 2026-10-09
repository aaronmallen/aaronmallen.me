# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Services
        class Row < Component
          prop :row, Blog::Types::Instance(Structs::ServiceRow)
          prop :selected, Blog::Types::Bool

          def view_template
            ListItem(title: @row.definition.name, href:, icon: @row.definition.icon, link:) do |item|
              item.meta { p(class: "li-sub") { sub } }
              StatusPill(status: @row.status)
            end
          end

          private

          def href = @selected ? path(:admin_services) : path(:admin_services, selected: @row.key)

          def link = @selected ? { aria: { current: "true" } } : Blog::Constants::EMPTY_HASH

          def sub
            span(class: "svc-account") { @row.account } if @row.account
            used_at = @row.connection&.last_used_at
            return unless used_at

            plain(DOT)
            Stamped(text: t(".used", time: Stamped::MARK), at: used_at)
          end
        end
      end
    end
  end
end
