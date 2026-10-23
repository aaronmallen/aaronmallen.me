# frozen_string_literal: true

module Agents
  module Repos
    class MemoryFileMutations < Blog::DB::Repo
      root :memory_files

      stamped_commands :create, :update
      commands delete: :by_pk
      tagged_by :memory_file_tags

      def last_description_event_id(memory_file_id) = memory_events.last_description_id(memory_file_id)

      def record(memory_file_id, change, **)
        update(memory_file_id, {})
        memory_events.by_pk(memory_events.command(:create).call(memory_file_id:, op: change, **).fetch(:id)).one
      end

      private

      def tag_project_id(id) = memory_files.by_pk(id).pluck(:project_id).first
    end
  end
end
