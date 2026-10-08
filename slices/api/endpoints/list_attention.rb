# frozen_string_literal: true

module API
  module Endpoints
    class ListAttention < Endpoint
      SCHEMA = { additionalProperties: false }.freeze
      REPLY = Helpers::Schema.object({ attention: Helpers::Schema.list(Serializers::Attention.reference) }).freeze

      include Deps[attention_queries: "activity.repos.attention_queries"]

      def handle = Success(attention: serialized(Serializers::Attention, attention_queries.stalled))
    end
  end
end
