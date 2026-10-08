# frozen_string_literal: true

module API
  module Serializers
    class DecisionTimelineEvent < Serializer
      KINDS = Blog::Types::DecisionEventKind.values.freeze

      SCHEMA = Helpers::Schema.object(
        {
          kind: { type: "string", enum: KINDS },
          id: { type: "integer", description: "the event's ID" },
          occurred_at: Helpers::Schema::STAMP,
          option_id: Helpers::Schema.nullable({ type: "integer", description: "the option added, edited or chosen" }),
          reason: Helpers::Schema.nullable({ type: "string", description: "why it was resolved, dropped or reopened" }),
          note: Helpers::Schema.nullable({ type: "string", description: "why the decision or option changed" }),
        },
      ).freeze

      schema_attributes
      stamps :occurred_at

      def id(entry) = entry.source_id
    end
  end
end
