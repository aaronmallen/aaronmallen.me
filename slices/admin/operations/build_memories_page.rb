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

      def call(scope: nil, query: nil, repo: nil, values: nil, errors: NO_ERRORS)
        scope = Blog::Types::MemoryScope.optional.fallback(nil)[scope]
        query = Blog::Types::OptionalText[query]
        files = memory_file_queries.listed(scope:, query:)
        live = project_queries.live_by_name
        repos = known_repos(live)
        shown_repo = shown(repo, repos)

        {
          files:, scope:, query:, repos:, errors:,
          counts: memory_file_queries.scope_counts,
          index: load_memory.call(repo: shown_repo),
          repo: shown_repo,
          scopes: scopes(files, live:, repos:),
          values: { path: "", scope: GLOBAL, **values.to_h },
        }
      end

      def scopes(files, live: project_queries.live_by_name, repos: known_repos(live))
        [
          choice(GLOBAL, nil, nil),
          *repos.map { choice("repo", it, it) },
          *projects(files, live).map { choice("project", it.id, it.name) },
          *tasks(files).map { choice("task", it.id, Blog::Helpers::Truncation.fit(it.title, limit: NAME_LIMIT)) },
        ]
      end

      private

      def choice(kind, target, name) = ScopeChoice.new(key: Helpers::MemoryScope.key_for(kind, target), kind:, name:)

      def known_repos(live) = (memory_file_queries.repos + live.filter_map(&:repo)).uniq.sort

      def projects(files, live) = (live + project_queries.by_ids(targets(files, :project_id))).uniq(&:id)

      def shown(repo, repos) = repos.include?(repo) ? repo : repos.first

      def targets(files, field) = files.filter_map { it[field] }.uniq

      def tasks(files) = (task_queries.open_choices + task_queries.by_ids(targets(files, :task_id))).uniq(&:id)
    end
  end
end
