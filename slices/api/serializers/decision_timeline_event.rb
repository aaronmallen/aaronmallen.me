# frozen_string_literal: true

module API
  module Serializers
    class DecisionTimelineEvent < Serializer
      KINDS = Blog::Types::DecisionEventKind.values.freeze

      SCHEMA = Schema.object(
        {
          kind: { type: "string", enum: KINDS },
          id: { type: "integer", description: "the event's ID" },
          occurred_at: Schema::STAMP,
          option_id: Schema.nullable({ type: "integer", description: "the option added, edited or chosen" }),
          reason: Schema.nullable({ type: "string", description: "why it was resolved, dropped or reopened" }),
          note: Schema.nullable({ type: "string", description: "why the decision or option changed" }),
        },
      ).freeze

      attributes :kind, :id, :occurred_at, :option_id, :reason, :note

      def id(entry) = entry.source_id

      def occurred_at(entry) = stamp(entry.occurred_at)
    end
  end
end
