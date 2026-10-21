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
          prop :written, Blog::Types::Array.of(Blog::Types::Hash)

          def view_template
            Card(title: t(".title")) do |card|
              card.side { Pill(color: :blue) { t(".running", count: @running) } } if @running.positive?
              lines
              @written.each { written(**it) }
            end
          end

          private

          def lines
            TodayLine(label: t(".sessions"), href: path(:admin_agent_sessions)) do
              t(".session_count", count: @sessions)
            end
            TodayLine(label: t(".memory"), href: path(:admin_memory_files)) do
              t(".memory_count", count: @memory_changes)
            end
            TodayLine(label: t(".artifacts"), href: path(:admin_artifacts)) { t(".artifact_count", count: @artifacts) }
          end

          def meta(artifact, current)
            p(class: "task-meta") do
              ArtifactType(type: artifact.type)
              span { t(".version", number: current.number) }
              span { Helpers::AgentBrand.author(current) || t(".you") }
              span { l(Blog::TimeZone.local(current.created_at), format: :clock) }
            end
          end

          def written(artifact:, current:)
            ListItem(title: artifact.title, href: path(:admin_artifact, id: artifact.id)) do |item|
              item.meta { meta(artifact, current) }
            end
          end
        end
      end
    end
  end
end
