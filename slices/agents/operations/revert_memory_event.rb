# frozen_string_literal: true

module Agents
  module Operations
    class RevertMemoryEvent < Blog::Operation
      ADD = Blog::Types::MemoryEventOp["add"]
      EDIT = Blog::Types::MemoryEventOp["edit"]
      REMOVE = Blog::Types::MemoryEventOp["remove"]
      REVERT = Blog::Types::MemoryEventOp["revert"]
      REVERTIBLE = [ADD, EDIT, REMOVE].freeze

      Undo = Data.define(:fact, :history)

      include SessionWrite
      include Deps[
        contract: "contracts.author_contract",
        memory_fact_mutations: "repos.memory_fact_mutations",
        memory_file_mutations: "repos.memory_file_mutations",
        memory_file_queries: "repos.memory_file_queries",
        touch_session: "operations.touch_session",
      ]

      def call(memory_file_id, id, params, at: Time.now)
        fields = step validate(params)
        step touch(fields)

        transaction do
          event = step revertible(memory_file_queries.event(memory_file_id, id))
          fact = memory_fact_mutations.for_update(memory_file_id, event.memory_fact_id)
          step unchanged(event)
          reverse(event, fact, author(fields), at)
        end
      end

      private

      def earlier_author(event) = { agent: event.was_agent, model: event.was_model }

      def earlier_text(event) = { type: event.was_type, text: event.was_text }

      def reverse(event, fact, by, at)
        undone = undo(event, fact, at)
        before = fact.removed? ? {} : fact.was

        memory_fact_mutations.update(fact.id, undone.fact)
        memory_file_mutations.record(
          fact.memory_file_id, REVERT,
          memory_fact_id: fact.id, reverted_event_id: event.id, **undone.history, **before, **by,
        )
      end

      def revertible(event)
        found(event).bind { REVERTIBLE.include?(it.op) ? Success(it) : Failure(:unrevertible) }
      end

      def unchanged(event)
        latest = memory_fact_mutations.last_event_id(event.memory_fact_id)
        latest == event.id ? Success(event) : Failure([:changed, latest])
      end

      def undo(event, fact, at)
        case event.op
          when ADD then Undo.new(fact: { removed_at: at }, history: {})
          when EDIT then Undo.new(fact: { **earlier_text(event), **earlier_author(event) },
                                  history: earlier_text(event))
          when REMOVE then Undo.new(fact: { removed_at: nil }, history: { type: fact.type, text: fact.text })
        end
      end
    end
  end
end
