# frozen_string_literal: true

module Decisions
  module Operations
    class TagDecision < Blog::Operation
      include Deps[decision_mutations: "repos.decision_mutations", decision_queries: "repos.decision_queries"]

      def call(id, name)
        transaction do
          step find(id)
          decision_mutations.add_tag(id, name)
          decision_queries.by_id(id)
        end
      end

      private

      def find(id) = found(decision_mutations.by_id_for_update(id) && id)
    end
  end
end
