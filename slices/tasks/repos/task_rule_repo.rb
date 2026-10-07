# frozen_string_literal: true

module Tasks
  module Repos
    class TaskRuleRepo < DB::Repo
      GITHUB = Blog::Types::TaskSourceProvider["github"]
      LINEAR = Blog::Types::TaskSourceProvider["linear"]
      TAG_SCOPE = Blog::Types::TagScope["private"]

      stamped_commands :create, :update
      commands delete: :by_pk

      def all = with_targets.order(:pattern, :provider).to_a

      def by_id(id) = with_targets.by_pk(id).one

      def link_projects(task_ids, project_ids) = record_links.link_projects(task_ids, project_ids)

      def matching_task_ids(rule)
        sources = task_sources.where(provider: rule.provider).unordered.pluck(:task_id, :url)

        sources.filter_map { |task_id, url| task_id if rule.matches?(origin(rule.provider, url)) }.uniq
      end

      def project_choices = projects.in_name_order.to_a

      def replace_projects(id, project_ids) = task_rule_projects.replace(id, project_ids)

      def replace_tags(id, names)
        tag_ids = tags.claim(names, scope: TAG_SCOPE).values_at(*names)
        task_rule_tags.replace(id, tag_ids)
        tag_ids
      end

      def tag_tasks(task_ids, tag_ids) = task_tags.add_missing(task_ids, tag_ids)

      def targets(provider, origin)
        found = origin&.downcase
        rules = found ? with_targets(task_rules.where(provider:)).to_a.select { it.matches?(found) } : []

        [rules.flat_map { it.tags.map(&:name) }, rules.flat_map { it.projects.map(&:id) }.uniq]
      end

      private

      def origin(provider, url)
        case provider
        when GITHUB then url.to_s[Record::GitHub::Issues::URL, :repo]
        when LINEAR then Record::Linear::Issues::URL.match(url.to_s)&.then { "#{it[:workspace]}/#{it[:team]}" }
        end.to_s.downcase
      end

      def with_targets(rules = task_rules) = rules.combine(:tags, :projects)
    end
  end
end
