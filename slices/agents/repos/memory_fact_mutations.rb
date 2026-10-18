# frozen_string_literal: true

module Agents
  module Repos
    class MemoryFactMutations < Blog::DB::Repo
      root :memory_facts

      stamped_commands :create, :update

      def for_update(memory_file_id, id) = memory_facts.where(memory_file_id:).by_pk(id).lock.one

      def last_event_id(memory_fact_id) = memory_events.where(memory_fact_id:).max(:id)
    end
  end
end
