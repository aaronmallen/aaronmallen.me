# frozen_string_literal: true

module Admin
  module Operations
    class BuildMemoriesPage
      ScopeChoice = Data.define(:key, :kind, :name)

      GLOBAL = Blog::Types::MemoryScope["global"]
      NAME_LIMIT = 48
      NO_ERRORS = Blog::Constants::EMPTY_HASH

      include Deps[
        load_memory: "agents.operations.load_memory",
        memory_file_queries: "agents.repos.memory_file_queries",
        project_queries: "projects.repos.project_queries",
        task_queries: "tasks.repos.task_queries",
      ]

      def call(scope: nil, query: nil, project: nil, values: nil, errors: NO_ERRORS)
        scope = Blog::Types::MemoryScope.optional.fallback(nil)[scope]
        query = Blog::Types::OptionalText[query]
        files = memory_file_queries.listed(scope:, query:)
        live = project_queries.live_by_name
        shown = shown(project, live)

        {
          files:, scope:, query:, errors:,
          **tallies(files),
          index: load_memory.call(project_id: shown&.id),
          project: shown&.id,
          projects: live,
          scopes: scopes(files, live:),
          values: { path: "", scope: GLOBAL, **values.to_h },
        }
      end

      def scopes(files, live: project_queries.live_by_name)
        [
          choice(GLOBAL, nil, nil),
          *projects(files, live).map { choice("project", it.id, it.name) },
          *tasks(files).map { choice("task", it.id, Blog::Helpers::Truncation.fit(it.title, limit: NAME_LIMIT)) },
        ]
      end

      private

      def choice(kind, target, name) = ScopeChoice.new(key: Helpers::MemoryScope.key_for(kind, target), kind:, name:)

      def projects(files, live) = (live + project_queries.by_ids(targets(files, :project_id))).uniq(&:id)

      def shown(project, live) = live.find { it.id.to_s == project.to_s } || live.first

      def tallies(files)
        {
          changes: memory_file_queries.agent_changes,
          counts: memory_file_queries.scope_counts,
          latest: memory_file_queries.latest_events(files.map(&:id)),
        }
      end

      def targets(files, field) = files.filter_map { it[field] }.uniq

      def tasks(files) = (task_queries.open_choices + task_queries.by_ids(targets(files, :task_id))).uniq(&:id)
    end
  end
end
