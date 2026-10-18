# frozen_string_literal: true

module Agents
  module Repos
    class MemoryFileQueries < Blog::DB::Repo
      def by_id(id) = memory_files.combine(:memory_facts).by_pk(id).one

      def event(memory_file_id, id) = memory_events.where(memory_file_id:).by_pk(id).one

      def history(memory_file_id) = memory_events.where(memory_file_id:).oldest_first.to_a

      def listed(scope: nil, query: nil)
        found = memory_files.combine(:memory_facts)
        found = found.where(scope:) if scope
        found = found.containing(query, :path, ids: holding(query)) if query

        found.in_load_order.to_a
      end

      def loaded(repo:, project_ids:, task_ids:)
        memory_files.combine(:memory_facts).loading(repo:, project_ids:, task_ids:).in_load_order.to_a
      end

      def repos = memory_files.exclude(repo: nil).order(:repo).distinct.pluck(:repo)

      def scope_counts = memory_files.tally(:scope, Blog::Types::MemoryScope.values)

      private

      def holding(query) = memory_facts.live_in_order.containing(query, :text).pluck(:memory_file_id).uniq
    end
  end
end
