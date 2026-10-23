# frozen_string_literal: true

module Admin
  module Actions
    module Agents
      class Sessions < Action
        include Deps[
          agent_session_queries: "agents.repos.agent_session_queries",
          project_queries: "projects.repos.project_queries",
          task_queries: "tasks.repos.task_queries",
        ]

        def handle(request, response)
          projects = project_queries.by_ids(agent_session_queries.project_ids).to_h { [it.id, it.name] }

          response.render(
            view,
            counts: agent_session_queries.today_counts, span: agent_session_queries.span, projects:,
            open: opened(request, projects), today: Blog::TimeZone.today, **listing(request),
          )
        end

        private

        def listing(request)
          page = Blog::Structs::Page.new(number: page_number(request), size: page_size)
          project = Blog::Types::IdParam[request.params[:project]]

          { sessions: agent_session_queries.listed(page, project_id: project), project: }
        end

        def opened(request, projects)
          id = Blog::Types::IdParam[request.params[:session]]
          session = id && agent_session_queries.by_id(id)
          return unless session

          {
            session:, project: projects[session.project_id], tasks: tasks(session),
            project_key: project_queries.keys([session.project_id])[session.project_id],
            memory_changes: agent_session_queries.memory_changes(id),
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
