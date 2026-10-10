# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Review
        class DecisionsCard < Component
          RESOLVED = Blog::Types::DecisionEventKind["resolved"]

          prop :decisions, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))

          def view_template
            Card(title: dotted(t(".title"), Blog::Helpers::Figures.count(@decisions.size)), id: "review-decisions") do
              next Empty { t(".empty") } if @decisions.empty?

              Capped(items: @decisions, more: path(:admin_decisions)) { row(it) }
            end
          end

          private

          def outcome(decision)
            return t(".dropped") unless decision.outcome == RESOLVED

            t(".resolved", option: Admin::Short.title(decision.chosen))
          end

          def row(decision)
            title = Admin::Short.title(decision.title)

            ListItem(title:, href: path(:admin_decision, id: decision.decision_id)) { plain outcome(decision) }
          end
        end
      end
    end
  end
end
