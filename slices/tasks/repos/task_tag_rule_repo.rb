# frozen_string_literal: true

module Tasks
  module Repos
    class TaskTagRuleRepo < Blog::DB::Repo
      GITHUB = Blog::Types::TaskSourceProvider["github"]
      LINEAR = Blog::Types::TaskSourceProvider["linear"]
      TAG_SCOPE = Blog::Types::TagScope["private"]

      commands :create, use: :timestamps, plugins_options: { timestamps: { timestamps: %i[created_at updated_at] } }
      commands update: :by_pk, use: :timestamps, plugins_options: { timestamps: { timestamps: %i[updated_at] } }
      commands delete: :by_pk

      def all = task_tag_rules.combine(:tags).order(:pattern, :provider).to_a

      def by_id(id) = task_tag_rules.combine(:tags).by_pk(id).one

      def matching_task_ids(rule)
        sources = task_sources.where(provider: rule.provider).unordered.pluck(:task_id, :url)

        sources.filter_map { |task_id, url| task_id if rule.matches?(origin(rule.provider, url)) }.uniq
      end

      def replace_tags(id, names)
        tag_ids = tags.claim(names, scope: TAG_SCOPE).values_at(*names)
        task_tag_rule_tags.replace(id, tag_ids)
        tag_ids
      end

      def tag_names_for(provider, origin)
        return Blog::Constants::EMPTY_ARRAY unless origin

        found = origin.downcase
        rules = task_tag_rules.where(provider:).combine(:tags).to_a
        rules.select { it.matches?(found) }.flat_map { it.tags.map(&:name) }
      end

      def tag_tasks(task_ids, tag_ids) = task_tags.add_missing(task_ids, tag_ids)

      private

      def origin(provider, url)
        case provider
        when GITHUB then url.to_s[Record::GitHub::Issues::URL, :repo]
        when LINEAR then Record::Linear::Issues::URL.match(url.to_s)&.then { "#{it[:workspace]}/#{it[:team]}" }
        end.to_s.downcase
      end
    end
  end
end
