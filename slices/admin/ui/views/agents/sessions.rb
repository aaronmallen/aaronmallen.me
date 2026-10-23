# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Agents
        class Sessions < View
          include Components::Agents

          LIVE_TABLES = %w[
            agent_session_index_lines agent_session_reads agent_session_search_hits agent_session_searches
            agent_session_tags agent_sessions artifact_versions artifacts memory_events memory_facts memory_files
            projects tags
          ].freeze

          prop :sessions, Blog::Types::Instance(Blog::Structs::Paged)
          prop :counts, Blog::Types::Hash
          prop :span, Blog::Types::Hash.optional
          prop :project, Blog::Types::Integer.optional
          prop :projects, Blog::Types::Hash.map(Blog::Types::Integer, Blog::Types::String)
          prop :open, Blog::Types::Hash.optional
          prop :today, Blog::Types::Date

          def view_template
            content_for(:live_tables, LIVE_TABLES)
            PageHead(title: t(".heading"), sub: lede) { project_filter unless @projects.empty? }

            Card(class: "agent-days", aria: { label: t(".label") }) { days }
            Pager(page: @sessions, route: :admin_agent_sessions, params: filter) unless @sessions.rows.empty?
            SessionDrawer(**@open.except(:project_key)) { session_tags } if @open
          end

          private

          def days
            return Empty { t(".empty") } if @sessions.rows.empty?

            @sessions.rows.group_by { Blog::TimeZone.local_date(it.started_at) }.each do |date, rows|
              section(class: "activity-day") do
                DayHead(date:, today: @today, count: rows.size, sunk: true)
                div(class: "activity-events") { rows.each { row(it) } }
              end
            end
          end

          def filter = @project ? { project: @project } : Blog::Constants::EMPTY_HASH

          def lede
            running = @counts[:running]
            today = t(".lede.today", count: @counts[:sessions])

            head = running.zero? ? "#{today}." : t(".lede.running", today:, count: running)
            @span ? "#{head} #{span}" : head
          end

          def place = { **filter, **@sessions.query }

          def project_filter
            options = { "" => t(".every_project"), **@projects.transform_keys(&:to_s) }

            AutoForm(action: path(:admin_agent_sessions)) do
              Select(name: "project", options:, selected: @project&.to_s, aria: { label: t(".project") })
              noscript { Button(type: "submit", small: true) { t(".show") } }
            end
          end

          def row(session) = SessionRow(session:, project: @projects[session.project_id], place:)

          def session_tags
            session = @open.fetch(:session)

            RecordTags(tags: session.tags, kind: :agent_session, id: session.id, project_key: @open[:project_key])
          end

          def span = t(".lede.span", sessions: @span[:sessions], count: [(@today - @span[:first]).to_i + 1, 1].max)
        end
      end
    end
  end
end
