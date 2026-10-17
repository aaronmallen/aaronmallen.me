# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Review
        class DecisionsCard < Component
          RESOLVED = Blog::Types::DecisionEventKind["resolved"]

          prop :decisions, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))

          def view_template
            empty = t(".empty") if @decisions.empty?

            Card(title: t(".title"), count: @decisions.size, empty:, id: "review-decisions") do
              Capped(items: @decisions, more: path(:admin_decisions)) { row(it) }
            end
          end

          private

          def outcome(decision)
            return t(".dropped") unless decision.outcome == RESOLVED

            t(".resolved", option: Helpers::Short.title(decision.chosen))
          end

          def row(decision)
            title = Helpers::Short.title(decision.title)

            id = decision.decision_id

            ListItem(
              title:, href: path(:admin_decision, id:), sub: outcome(decision),
              data: { menu: path(:admin_decision_menu, id:) },
            )
          end
        end
      end
    end
  end
end
