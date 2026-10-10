# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Decisions
        class StatusTabs < Component
          LABELS = {
            Blog::Types::DecisionStatus["open"] => "ui.components.status_pill.open",
            Blog::Types::DecisionStatus["resolved"] => "ui.components.status_pill.resolved",
            Blog::Types::DecisionStatus["dropped"] => "ui.components.status_pill.dropped",
          }.freeze

          prop :counts, Blog::Types::Hash.map(Blog::Types::String, Blog::Types::Integer)
          prop :filter, Blog::Types::DecisionStatus

          def view_template
            nav(class: "screen-tabs-list decision-tabs", aria: { label: t(".label") }) { LABELS.each { tab(*it) } }
          end

          private

          def tab(status, label)
            current = status == @filter

            a(class: "screen-tab", href: path(:admin_decisions, status:), aria: { current: ("page" if current) }) do
              plain t(label)
              span(class: "decision-tab-count") { @counts.fetch(status, 0).to_s }
            end
          end
        end
      end
    end
  end
end
