# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Agents
        class Sessions < View
          include Components::Agents

          LIVE_TABLES = %w[
            agent_session_index_lines agent_session_reads agent_session_search_hits agent_session_searches
            agent_sessions artifact_versions artifacts memory_events memory_files
          ].freeze

          prop :sessions, Blog::Types::Instance(Blog::Structs::Paged)
          prop :counts, Blog::Types::Hash
          prop :open, Blog::Types::Hash.optional
          prop :today, Blog::Types::Date

          def view_template
            content_for(:live_tables, LIVE_TABLES)
            PageHead(title: t(".heading"), sub: lede)

            section(class: "agent-days", aria: { label: t(".label") }) { days }
            SessionDrawer(**@open) if @open
          end

          private

          def days
            return Empty { t(".empty") } if @sessions.rows.empty?

            @sessions.rows.group_by { Blog::TimeZone.local_date(it.started_at) }.each do |date, rows|
              section do
                DayHead(date:, today: @today, count: rows.size)
                rows.each { SessionRow(session: it, place:) }
              end
            end
            Pager(page: @sessions, route: :admin_agent_sessions)
          end

          def lede
            running = @counts[:running]
            today = t(".lede.today", count: @counts[:sessions])

            running.zero? ? "#{today}." : t(".lede.running", today:, count: running)
          end

          def place = @sessions.query
        end
      end
    end
  end
end
