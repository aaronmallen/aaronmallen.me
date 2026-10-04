# frozen_string_literal: true

module API
  module Endpoints
    class ListAttention < Endpoint
      SCHEMA = { additionalProperties: false }.freeze
      REPLY = Schema.object({ attention: Schema.list(Serializers::Attention.reference) }).freeze

      include Deps[stalled_list: "activity.queries.stalled_list"]

      def handle = Success(attention: serialized(Serializers::Attention, stalled_list.call))
    end
  end
end
