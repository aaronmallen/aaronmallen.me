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

      schema_attributes
      stamps :created_at, :updated_at
      tag_names

      def options(decision) = DecisionOption.new(decision.options).serializable_hash
    end
  end
end
