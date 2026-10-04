# frozen_string_literal: true

module API
  module Serializers
    class DecisionChoice < Serializer
      SCHEMA = Schema.object(
        {
          option: DecisionOption.reference,
          reason: { type: "string", description: "why that option won, in Markdown" },
          resolved_at: Schema::STAMP,
        },
      ).freeze

      attributes :option, :reason, :resolved_at

      def option(_resolved) = DecisionOption.new(params.fetch(:option)).serializable_hash

      def resolved_at(resolved) = stamp(resolved.occurred_at)
    end
  end
end
