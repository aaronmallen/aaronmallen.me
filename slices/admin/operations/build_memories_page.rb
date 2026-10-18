# frozen_string_literal: true

module Admin
  module Operations
    class BuildMemoriesPage
      Scope = Data.define(:key, :scope, :name)

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
        repos = repos()
        repo = repos.first unless repos.include?(repo)

        {
          files:, scope:, query:, repo:, repos:, errors:,
          counts: memory_file_queries.scope_counts,
          loads: load_memory.call(repo:),
          scopes: scopes(files),
          values: { path: "", scope: GLOBAL, **values.to_h },
        }
      end

      def scopes(files)
        [
          Scope.new(key: GLOBAL, scope: GLOBAL, name: nil),
          *repos.map { scoped("repo", it, it) },
          *projects(files).map { scoped("project", it.id, it.name) },
          *tasks(files).map { scoped("task", it.id, Blog::Helpers::Truncation.fit(it.title, limit: NAME_LIMIT)) },
        ]
      end

      private

      def projects(files)
        (project_queries.live_by_name + project_queries.by_ids(targets(files, :project_id))).uniq(&:id)
      end

      def repos = (memory_file_queries.repos + project_queries.live_by_name.filter_map(&:repo)).uniq.sort

      def scoped(scope, target, name)
        Scope.new(key: "#{scope}#{Helpers::MemoryScope::SEPARATOR}#{target}", scope:, name:)
      end

      def targets(files, field) = files.filter_map { it[field] }.uniq

      def tasks(files) = (task_queries.open_choices + task_queries.by_ids(targets(files, :task_id))).uniq(&:id)
    end
  end
end
