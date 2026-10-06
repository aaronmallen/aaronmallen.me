# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Decisions
        class Row < Component
          prop :decision, Blog::Types::Instance(ROM::Struct)

          def view_template
            ListItem(title: @decision.title, href: path(:admin_decision, id: @decision.id)) do |item|
              item.beside { RecordKey(kind: "decision", id: @decision.id) }
              item.meta { p(class: "li-sub") { sub } }
            end
          end

          private

          def sub
            text = dotted(t(".options", count: @decision.options.size), t(".opened", date: Stamped::MARK))

            Stamped(text:, at: @decision.created_at)
          end
        end
      end
    end
  end
end
