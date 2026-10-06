# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Decisions
        class Status < Component
          STATUSES = {
            Blog::Types::DecisionStatus["open"] => [:blue, "fa-regular fa-circle", ".open"],
            Blog::Types::DecisionStatus["resolved"] => [:green, "fa-solid fa-circle-check", ".resolved"],
            Blog::Types::DecisionStatus["dropped"] => [:sand, "fa-solid fa-ban", ".dropped"],
          }.freeze

          prop :status, Blog::Types::DecisionStatus

          def view_template
            color, icon, label_key = STATUSES.fetch(@status)

            Pill(color:, icon:) { t(label_key) }
          end
        end
      end
    end
  end
end
