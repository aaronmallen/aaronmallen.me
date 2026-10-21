# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Agents
        class SessionRow < Component
          OWNER_SEPARATOR = "/"

          prop :session, Blog::Types::Instance(ROM::Struct)
          prop :place, Blog::Types::Hash

          def view_template
            href = path(:admin_agent_sessions, **@place, session: @session.id)

            div(id: "agent-session-#{@session.id}") do
              ListItem(title: @session.title, href:) do |item|
                item.meta { p(class: "task-meta") { meta } }
                side
              end
            end
          end

          private

          def clock(time) = l(Blog::TimeZone.local(time), format: :clock)

          def counts
            span { t(".read", count: @session.agent_session_reads.size) }
            span { t(".searches", count: @session.agent_session_searches.size) }
            span { t(".changes", count: @session.memory_events.size) } if @session.memory_events.any?
            span { t(".artifacts", count: @session.artifact_versions.size) } if @session.artifact_versions.any?
          end

          def meta
            span { period }
            span(title: t(".via", agent: @session.agent)) { Helpers::AgentBrand.model(@session.model) }
            repo
            counts
          end

          def period
            from = clock(@session.started_at)
            to = @session.ended_at ? clock(@session.ended_at) : t(".now")

            t(".span", from:, to:)
          end

          def repo
            return unless @session.repo

            name = @session.repo.split(OWNER_SEPARATOR).last
            span do
              Icon("fa-brands fa-github")
              whitespace
              plain @session.branch ? t(".branch", repo: name, branch: @session.branch) : name
            end
          end

          def side
            return Pill(color: :blue) { t(".running") } unless @session.ended_at

            span { Blog::Helpers::Figures.elapsed(@session.ended_at - @session.started_at) }
          end
        end
      end
    end
  end
end
