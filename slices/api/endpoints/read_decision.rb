# frozen_string_literal: true

module API
  module Endpoints
    class ReadDecision < Endpoint
      SCHEMA = Schema.by_id

      KIND = Blog::Types::RecordKind["decision"]
      RESOLVED = Blog::Types::DecisionEventKind["resolved"]
      TIMELINE = "the decision's comments and events, oldest first"

      ENTRIES = [Serializers::DecisionTimelineComment, Serializers::DecisionTimelineEvent].freeze

      SERIALIZERS = ENTRIES.flat_map { |serializer| serializer::KINDS.map { [it, serializer] } }.to_h.freeze

      CHOICE = {
        oneOf: [Serializers::DecisionChoice.reference, { type: "null" }],
        description: "the option the decision was resolved with and why; null unless it is resolved",
      }.freeze

      REPLY = Schema.widen(
        Serializers::Decision::SCHEMA,
        choice: CHOICE,
        comments: Schema.list(Serializers::DecisionComment.reference),
        record_links: Serializers::Link::GROUPS,
        timeline: Schema.list({ oneOf: ENTRIES.map(&:reference) }).merge(description: TIMELINE),
      ).freeze

      include Deps[
        decision_by_id: "decisions.queries.by_id",
        decision_comments: "decisions.queries.comments",
        decision_timeline: "decisions.queries.timeline",
        record_links: "links.queries.record_links",
      ]

      def handle(id:)
        decision = decision_by_id.call(id)
        return not_found(Wording.missing("decision", id)) if decision.nil?

        Success(answered(decision, decision_timeline.call(decision.id)))
      end

      private

      def answered(decision, timeline)
        serialized(Serializers::Decision, decision).merge(
          choice: choice(decision, timeline),
          comments: serialized(Serializers::DecisionComment, decision_comments.call(decision.id)),
          record_links: linked(KIND, decision.id),
          timeline: timeline.map { serialized(SERIALIZERS.fetch(it.kind), it) },
        )
      end

      def choice(decision, timeline)
        option = decision.options.find { it.id == decision.resolved_option_id }
        resolved = timeline.rfind { it.kind == RESOLVED }
        return unless option && resolved

        serialized(Serializers::DecisionChoice, resolved, option:)
      end
    end
  end
end
