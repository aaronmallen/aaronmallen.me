# frozen_string_literal: true

module API
  module Serializers
    class TaskComment < Serializer
      LOCAL = "local"

      SCHEMA = Helpers::Schema.object(
        {
          id: Helpers::Schema::INTEGER,
          body: { type: "string", description: "the comment, in Markdown" },
          author: Helpers::Schema.nullable(Helpers::Schema::STRING),
          source: { type: "string", enum: [LOCAL, *Blog::Types::TaskSourceProvider.values] },
          url: Helpers::Schema.nullable(Helpers::Schema::STRING),
          created_at: Helpers::Schema::STAMP,
          updated_at: Helpers::Schema::STAMP,
        },
      ).freeze

      schema_attributes
      stamps :created_at, :updated_at

      def author(comment) = comment.remote_id ? comment.author : Hanami.app.settings.owner_name

      def source(comment) = comment.provider || LOCAL
    end
  end
end
