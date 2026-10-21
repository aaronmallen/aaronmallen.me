# frozen_string_literal: true

module Admin
  module Actions
    module Agents
      class Sessions < Action
        include Deps[
          agent_session_queries: "agents.repos.agent_session_queries", task_queries: "tasks.repos.task_queries",
        ]

        def handle(request, response)
          page = Blog::Structs::Page.new(number: page_number(request), size: page_size)

          response.render(
            view,
            sessions: agent_session_queries.listed(page), counts: agent_session_queries.today_counts,
            span: agent_session_queries.span,
            open: opened(Blog::Types::IdParam[request.params[:session]]), today: Blog::TimeZone.today,
          )
        end

        private

        def opened(id)
          session = id && agent_session_queries.by_id(id)
          return unless session

          {
            session:, tasks: tasks(session), memory_changes: agent_session_queries.memory_changes(id),
            artifacts: agent_session_queries.artifact_writes(id),
          }
        end

        def tasks(session)
          ids = session.agent_session_tasks.map(&:task_id)

          task_queries.by_ids(ids).sort_by { ids.index(it.id) }
        end
      end
    end
  end
end
