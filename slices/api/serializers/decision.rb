# frozen_string_literal: true

module API
  module Serializers
    class Decision < Serializer
      SCHEMA = Schema.object(
        {
          id: Schema::INTEGER,
          title: Schema::STRING,
          problem: { type: "string", description: "the problem, in Markdown" },
          status: { type: "string", enum: Blog::Types::DecisionStatus.values },
          resolved_option_id: Schema.nullable({ type: "integer", description: "the option it was resolved with" }),
          tags: Schema::TAGS,
          options: Schema.list(DecisionOption.reference),
          created_at: Schema::STAMP,
          updated_at: Schema::STAMP,
        },
      ).freeze

      attributes :id, :title, :problem, :status, :resolved_option_id, :tags, :options, :created_at, :updated_at

      def created_at(decision) = stamp(decision.created_at)

      def options(decision) = DecisionOption.new(decision.options).serializable_hash

      def tags(decision) = decision.tags.map(&:name)

      def updated_at(decision) = stamp(decision.updated_at)
    end
  end
end
