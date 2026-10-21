# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Agents
        class AgentMark < Component
          prop :model, Blog::Types::String

          def view_template
            span(class: "agent-mark", title: t(".title", who: Helpers::AgentBrand.model(@model))) do
              Icon("fa-solid fa-robot", label: t(".label"))
            end
          end
        end
      end
    end
  end
end
