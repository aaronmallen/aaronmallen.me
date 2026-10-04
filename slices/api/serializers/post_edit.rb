# frozen_string_literal: true

module API
  module Serializers
    class PostEdit < Serializer
      SCHEMA = Schema.object(
        {
          id: Schema::INTEGER,
          note: { type: "string", description: "what changed in the published post, and why" },
          created_at: Schema::STAMP,
          updated_at: Schema::STAMP,
        },
      ).freeze

      attributes :id, :note, :created_at, :updated_at

      def created_at(edit) = stamp(edit.created_at)

      def updated_at(edit) = stamp(edit.updated_at)
    end
  end
end
