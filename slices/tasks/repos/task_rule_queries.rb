# frozen_string_literal: true

module Tasks
  module Repos
    class TaskRuleQueries < Blog::DB::Repo
      GITHUB = Blog::Types::TaskSourceProvider["github"]
      LINEAR = Blog::Types::TaskSourceProvider["linear"]

      include Deps[project_queries: "projects.repos.project_queries"]

      def all = with_projects(with_targets.order(:pattern, :provider).to_a)

      def by_id(id) = with_projects(with_targets.by_pk(id).to_a).first

      def matching_task_ids(rule) = task_ids_from(rule.provider) { rule.matches?(it) }

      def project_choices = project_queries.by_name

      def repo_task_ids(repo) = task_ids_from(GITHUB) { it == repo }

      def targets(provider, origin)
        found = origin&.downcase
        rules = found ? with_targets(task_rules.where(provider:)).to_a.select { it.matches?(found) } : []

        ids = [*owners(provider, found), *rules.flat_map { project_ids(it) }]

        [rules.flat_map { it.tags.map(&:name) }, ids.uniq]
      end

      private

      def origin(provider, url)
        case provider
          when GITHUB then url.to_s[Record::GitHub::Issues::URL, :repo]
          when LINEAR then Record::Linear::Issues::URL.match(url.to_s)&.then { "#{it[:workspace]}/#{it[:team]}" }
        end.to_s.downcase
      end

      def owners(provider, repo) = provider == GITHUB && repo ? project_queries.ids_by_repo(repo) : []

      def project_ids(rule) = rule.task_rule_projects.map(&:project_id)

      def task_ids_from(provider)
        sources = task_sources.where(provider:).unordered.pluck(:task_id, :url)

        sources.filter_map { |task_id, url| task_id if yield(origin(provider, url)) }.uniq
      end

      def with_projects(rules)
        found = project_queries.by_ids(rules.flat_map { project_ids(it) }.uniq)

        rules.map { |rule| rule.new(projects: found.select { project_ids(rule).include?(it.id) }) }
      end

      def with_targets(rules = task_rules) = rules.combine(:tags, :task_rule_projects)
    end
  end
end
