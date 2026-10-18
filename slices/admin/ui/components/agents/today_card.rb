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
            Card(title: t(".title")) do |card|
              card.side { Pill(color: :blue) { t(".running", count: @running) } } if @running.positive?
              lines
            end
          end

          private

          def lines
            sessions = path(:admin_agent_sessions)

            TodayLine(label: t(".sessions"), href: sessions) { t(".session_count", count: @sessions) }
            TodayLine(label: t(".memory"), href: path(:admin_agent_memories)) do
              t(".memory_count", count: @memory_changes)
            end
            TodayLine(label: t(".artifacts"), href: sessions) { t(".artifact_count", count: @artifacts) }
          end
        end
      end
    end
  end
end
