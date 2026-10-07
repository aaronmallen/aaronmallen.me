# frozen_string_literal: true

module Tags
  module Repos
    class TagQueries < DB::Repo
      include Deps[
        decision_queries: "decisions.repos.decision_queries",
        journal_entry_queries: "record.repos.journal_entry_queries",
        post_queries: "posts.repos.post_queries",
        project_queries: "projects.repos.project_queries",
        task_queries: "tasks.repos.task_queries",
      ]

      def all_in(scope) = tags.in_scope(scope).in_name_order.to_a

      def count_matching(scope, text) = matching(scope, text).count

      def find_in(scope, id) = tags.in_scope(scope).by_pk(id).one

      def last_tag_of_rules(id) = tags.last_tag_of_rules(id)

      def next_color(scope:) = tags.next_color(scope:)

      def page_matching(scope, text, page) = page.fill(matching(scope, text).in_name_order.paged(page).to_a)

      def summary(name)
        found = tags.by_names(name).to_a
        return if found.empty?

        Structs::Summary.new(
          name:, tags: found, posts: post_queries.by_tag(name), projects: project_queries.by_tag(name),
          tasks: task_queries.by_tag(name), journal_entries: journal_entry_queries.by_tag(name),
          decisions: decision_queries.by_tag(name),
        )
      end

      def usage(scope:)
        by_kind = tags.counts_by_kind(scope)

        by_kind.values.flat_map(&:keys).uniq.to_h do |id|
          [id, by_kind.filter_map { |kind, counts| [kind, counts[id]] if counts[id] }.to_h]
        end
      end

      private

      def matching(scope, text) = tags.in_scope(scope).naming(text)
    end
  end
end
