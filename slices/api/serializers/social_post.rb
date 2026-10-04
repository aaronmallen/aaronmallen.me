# frozen_string_literal: true

module API
  module Serializers
    class SocialPost < Serializer
      SCHEMA = Schema.object(
        {
          id: Schema::INTEGER,
          status: { type: "string", enum: Blog::Types::SocialPostStatus.values },
          post_id: Schema.nullable(Schema::INTEGER),
          posted_at: Schema.nullable(Schema::STAMP),
          parts: { type: "array", items: Schema::STRING, description: "the text of each part, in order" },
        },
      ).freeze

      attributes :id, :status, :post_id, :posted_at, :parts

      def parts(social_post) = social_post.parts.map(&:body)

      def posted_at(social_post) = stamp(social_post.posted_at)
    end
  end
end
