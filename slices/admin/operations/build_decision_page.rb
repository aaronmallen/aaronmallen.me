# frozen_string_literal: true

module Admin
  module Operations
    class BuildDecisionPage
      include Blog::Constants

      KIND = Blog::Types::RecordKind["decision"]

      include Deps[
        decision_by_id: "decisions.queries.by_id",
        decision_timeline: "decisions.queries.timeline",
        list_record_links: "operations.list_record_links",
      ]

      def call(id, form: EMPTY_HASH, records: EMPTY_HASH)
        decision = decision_by_id.call(id)
        return unless decision

        { decision:, form:, timeline: decision_timeline.call(decision.id),
          records: list_record_links.call(KIND, decision.id, **records) }
      end
    end
  end
end
