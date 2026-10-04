# frozen_string_literal: true

module API
  module Serializers
    class DecisionOption < Serializer
      SCHEMA = Schema.object(
        {
          id: Schema::INTEGER,
          title: Schema::STRING,
          body: { type: "string", description: "the option, in Markdown" },
          created_at: Schema::STAMP,
          updated_at: Schema::STAMP,
        },
      ).freeze

      attributes :id, :title, :body, :created_at, :updated_at

      def created_at(option) = stamp(option.created_at)

      def updated_at(option) = stamp(option.updated_at)
    end
  end
end
