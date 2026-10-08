# frozen_string_literal: true

module API
  module Serializers
    class Decision < Serializer
      SCHEMA = Helpers::Schema.object(
        {
          id: Helpers::Schema::INTEGER,
          title: Helpers::Schema::STRING,
          problem: { type: "string", description: "the problem, in Markdown" },
          status: { type: "string", enum: Blog::Types::DecisionStatus.values },
          resolved_option_id: Helpers::Schema.nullable(
            { type: "integer", description: "the option it was resolved with" },
          ),
          tags: Helpers::Schema::TAGS,
          options: Helpers::Schema.list(DecisionOption.reference),
          created_at: Helpers::Schema::STAMP,
          updated_at: Helpers::Schema::STAMP,
        },
      ).freeze

      schema_attributes
      stamps :created_at, :updated_at
      tag_names

      def options(decision) = DecisionOption.new(decision.options).serializable_hash
    end
  end
end
