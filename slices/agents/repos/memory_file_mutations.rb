# frozen_string_literal: true

module Agents
  module Repos
    class MemoryFileMutations < Blog::DB::Repo
      root :memory_files

      stamped_commands :create, :update
      commands delete: :by_pk

      def by_id_for_update(id) = memory_files.by_pk(id).lock.one

      def last_description_event_id(memory_file_id) = memory_events.last_description_id(memory_file_id)

      def record(memory_file_id, change, **)
        update(memory_file_id, {})
        memory_events.by_pk(memory_events.command(:create).call(memory_file_id:, op: change, **).fetch(:id)).one
      end
    end
  end
end
