# frozen_string_literal: true

module Agents
  module Operations
    class RevertMemoryEvent < Blog::Operation
      ADD = Blog::Types::MemoryEventOp["add"]
      EDIT = Blog::Types::MemoryEventOp["edit"]
      REVERT = Blog::Types::MemoryEventOp["revert"]
      REVERTIBLE = [ADD, EDIT, Blog::Types::MemoryEventOp["remove"]].freeze

      include SessionWrite
      include Deps[
        contract: "contracts.author_contract",
        memory_fact_mutations: "repos.memory_fact_mutations",
        memory_file_mutations: "repos.memory_file_mutations",
        memory_file_queries: "repos.memory_file_queries",
      ]

      def call(memory_file_id, id, params, at: Time.now)
        author = step validate(params)

        transaction do
          event = step revertible(memory_file_queries.event(memory_file_id, id))
          fact = memory_fact_mutations.for_update(memory_file_id, event.memory_fact_id)
          step unchanged(event)
          restore(event, fact, author, at)
        end
      end

      private

      def earlier(event) = { type: event.was_type, text: event.was_text }

      def earlier_author(event) = { agent: event.was_agent, model: event.was_model }

      def restore(event, fact, author, at)
        changes, after = restored(event, fact, at)
        before = fact.removed? ? {} : fact.was

        memory_fact_mutations.update(fact.id, changes)
        memory_file_mutations.record(
          fact.memory_file_id, REVERT,
          memory_fact_id: fact.id, reverted_event_id: event.id, **after, **before, **author,
        )
      end

      def restored(event, fact, at)
        case event.op
          when ADD then [{ removed_at: at }, {}]
          when EDIT then [{ **earlier(event), **earlier_author(event) }, earlier(event)]
          else [{ removed_at: nil }, { type: fact.type, text: fact.text }]
        end
      end

      def revertible(event)
        found(event).bind { REVERTIBLE.include?(it.op) ? Success(it) : Failure(:unrevertible) }
      end

      def unchanged(event)
        latest = memory_fact_mutations.last_event_id(event.memory_fact_id)
        latest == event.id ? Success(event) : Failure([:changed, latest])
      end
    end
  end
end
