# frozen_string_literal: true

module Admin
  module Operations
    class BuildDecisionPage
      include Blog::Constants

      KIND = Blog::Types::RecordKind["decision"]

      include Deps[
        decision_queries: "decisions.repos.decision_queries",
        list_record_links: "operations.list_record_links",
      ]

      def call(id, form: EMPTY_HASH, records: EMPTY_HASH)
        decision = decision_queries.by_id(id)
        return unless decision

        { decision:, form:, timeline: decision_queries.timeline(decision.id),
          records: list_record_links.call(KIND, decision.id, **records) }
      end
    end
  end
end
