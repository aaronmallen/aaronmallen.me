# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Agents
        class TodayCard < Component
          prop :sessions, Blog::Types::Integer
          prop :running, Blog::Types::Integer
          prop :memory_changes, Blog::Types::Integer
          prop :artifacts, Blog::Types::Integer

          def view_template
            href = path(:admin_agent_sessions)

            Card(title: t(".title")) do |card|
              card.side { Pill(color: :blue) { t(".running", count: @running) } } if @running.positive?
              TodayLine(label: t(".sessions"), href:) { t(".session_count", count: @sessions) }
              TodayLine(label: t(".memory"), href:) { t(".memory_count", count: @memory_changes) }
              TodayLine(label: t(".artifacts"), href:) { t(".artifact_count", count: @artifacts) }
            end
          end
        end
      end
    end
  end
end
