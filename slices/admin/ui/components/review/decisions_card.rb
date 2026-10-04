# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Review
        class DecisionsCard < Component
          RESOLVED = Blog::Types::DecisionEventKind["resolved"]
          TEXT_LIMIT = 80

          prop :decisions, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))

          def view_template
            Card(title: t(".title"), id: "review-decisions") do
              next Empty { t(".empty") } if @decisions.empty?

              @decisions.each { ListItem(**item(it)) }
            end
          end

          private

          def item(decision)
            {
              title: Blog::Truncation.cut(decision.title, keep: TEXT_LIMIT),
              href: path(:admin_decision, id: decision.decision_id),
              sub: sub(decision),
            }
          end

          def sub(decision)
            day = l(decision.closed_on, format: :weekday)
            return t(".dropped", day:) unless decision.outcome == RESOLVED

            t(".resolved", option: Blog::Truncation.cut(decision.chosen, keep: TEXT_LIMIT), day:)
          end
        end
      end
    end
  end
end
