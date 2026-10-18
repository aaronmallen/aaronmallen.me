# frozen_string_literal: true

module Agents
  module Repos
    class MemoryFileQueries < Blog::DB::Repo
      def by_id(id) = memory_files.combine(:memory_facts).by_pk(id).one

      def event(memory_file_id, id) = memory_events.where(memory_file_id:).by_pk(id).one

      def history(memory_file_id) = memory_events.where(memory_file_id:).oldest_first.to_a

      def loaded(repo:, project_ids:, task_ids:)
        memory_files.combine(:memory_facts).loading(repo:, project_ids:, task_ids:).in_load_order.to_a
      end
    end
  end
end
