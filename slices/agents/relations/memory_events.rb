# frozen_string_literal: true

module Agents
  module Relations
    class MemoryEvents < Blog::DB::Relation
      DESCRIBED = %w[describe revert].map { Blog::Types::MemoryEventOp[it] }.freeze

      schema :memory_events, infer: true do
        associations do
          belongs_to :memory_file
        end
      end

      def last_description_id(memory_file_id) = where(memory_file_id:, memory_fact_id: nil, op: DESCRIBED).max(:id)

      def latest_by_fact(memory_fact_ids)
        where(memory_fact_id: memory_fact_ids).dataset.unordered.group(:memory_fact_id)
                                              .select_hash(:memory_fact_id, Sequel.function(:max, :id).as(:id))
      end

      def latest_by_file(memory_file_ids)
        where(memory_file_id: memory_file_ids).distinct(:memory_file_id).order(:memory_file_id, self[:id].desc)
      end

      def session_changes
        join(:memory_files, id: self[:memory_file_id].qualified)
          .select_append(memory_files[:path].qualified)
          .order(self[:id].qualified.asc)
      end

      def session_listed = select(:id, :memory_file_id, :memory_fact_id, :op, :session_id).order(self[:id].asc)
    end
  end
end
