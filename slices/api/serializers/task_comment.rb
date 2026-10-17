# frozen_string_literal: true

module API
  module Serializers
    class TaskComment < Serializer
      LOCAL = "local"

      SCHEMA = Helpers::Schema.object(
        {
          id: Helpers::Schema::INTEGER,
          body: Helpers::Schema::COMMENT,
          author: Helpers::Schema.nullable(Helpers::Schema::STRING),
          source: { type: "string", enum: [LOCAL, *Blog::Types::TaskSourceProvider.values] },
          url: Helpers::Schema.nullable(Helpers::Schema::STRING),
          created_at: Helpers::Schema::STAMP,
          updated_at: Helpers::Schema::STAMP,
        },
      ).freeze

      schema_attributes
      stamps :created_at, :updated_at
      untrusted :body

      def author(comment) = comment.remote_id ? untrusted(comment.author) : params.fetch(:owner)

      def source(comment) = comment.provider || LOCAL
    end
  end
end
