# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Agents
        class Sessions < View
          include Components::Agents

          LIVE_TABLES = %w[
            agent_session_index_lines agent_session_reads agent_session_search_hits agent_session_searches
            agent_sessions artifact_versions artifacts memory_events memory_facts memory_files
          ].freeze

          prop :sessions, Blog::Types::Instance(Blog::Structs::Paged)
          prop :counts, Blog::Types::Hash
          prop :span, Blog::Types::Hash.optional
          prop :open, Blog::Types::Hash.optional
          prop :today, Blog::Types::Date

          def view_template
            content_for(:live_tables, LIVE_TABLES)
            PageHead(title: t(".heading"), sub: lede)

            Card(class: "agent-days", aria: { label: t(".label") }) { days }
            Pager(page: @sessions, route: :admin_agent_sessions) unless @sessions.rows.empty?
            SessionDrawer(**@open) if @open
          end

          private

          def days
            return Empty { t(".empty") } if @sessions.rows.empty?

            @sessions.rows.group_by { Blog::TimeZone.local_date(it.started_at) }.each do |date, rows|
              section(class: "activity-day") do
                DayHead(date:, today: @today, count: rows.size, sunk: true)
                div(class: "activity-events") { rows.each { SessionRow(session: it, place:) } }
              end
            end
          end

          def lede
            running = @counts[:running]
            today = t(".lede.today", count: @counts[:sessions])

            head = running.zero? ? "#{today}." : t(".lede.running", today:, count: running)
            @span ? "#{head} #{span}" : head
          end

          def place = @sessions.query

          def span = t(".lede.span", sessions: @span[:sessions], count: [(@today - @span[:first]).to_i + 1, 1].max)
        end
      end
    end
  end
end
