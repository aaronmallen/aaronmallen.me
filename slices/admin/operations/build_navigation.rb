# frozen_string_literal: true

module Admin
  module Operations
    class BuildNavigation
      include Deps[
        "i18n", "operations.list_actions", "operations.list_sections",
        inbox_queries: "api.repos.inbox_queries", artifact_queries: "agents.repos.artifact_queries",
        memory_file_queries: "agents.repos.memory_file_queries",
        agent_session_queries: "agents.repos.agent_session_queries", note_queries: "notes.repos.note_queries",
      ]

      def call(current_path:)
        inbox = inbox_queries.unseen_counts
        sections = list_sections.call(current_path:, inbox: inbox.values.sum)

        Structs::Navigation.new(sections: noted(sections), actions: list_actions.call, inbox:)
      end

      private

      def agent_notes
        {
          memories: i18n.t("ui.components.nav.screen_tabs.notes.facts", count: memory_file_queries.fact_count),
          artifacts: artifact_queries.count_by_type.values.sum.to_s,
          sessions: sessions_note,
        }
      end

      def noted(sections)
        notes = case sections.find(&:current)&.group
                  when :agents then agent_notes
                  when :journal then { notes: Blog::Helpers::Figures.count(note_queries.count) }
                end
        return sections unless notes

        sections.map { it.with(note: notes[it.name]) }
      end

      def sessions_note
        counts = agent_session_queries.today_counts
        running = counts[:running]
        return i18n.t("ui.components.nav.screen_tabs.notes.running", count: running) if running.positive?

        i18n.t("ui.components.nav.screen_tabs.notes.today", count: counts[:sessions])
      end
    end
  end
end
