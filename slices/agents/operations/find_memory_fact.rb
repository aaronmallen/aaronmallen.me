# frozen_string_literal: true

module Agents
  module Operations
    class FindMemoryFact < Blog::Operation
      include Deps[memory_fact_mutations: "repos.memory_fact_mutations"]

      def call(memory_file_id, id)
        fact = step found(memory_fact_mutations.for_update(memory_file_id, id))
        step live(fact)
      end

      private

      def live(fact) = fact.removed? ? Failure(:removed) : Success(fact)
    end
  end
end
