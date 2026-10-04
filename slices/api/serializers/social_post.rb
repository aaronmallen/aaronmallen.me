# frozen_string_literal: true

module API
  module Serializers
    class SocialPost < Serializer
      SCHEMA = Schema.object(
        {
          id: Schema::INTEGER,
          status: { type: "string", enum: Blog::Types::SocialPostStatus.values },
          post_id: Schema.nullable(Schema::INTEGER),
          targets: Schema.list({ type: "string", enum: Blog::Types::NetworkName.values }),
          posted_at: Schema.nullable(Schema::STAMP),
          created_at: Schema::STAMP,
          updated_at: Schema::STAMP,
          parts: { type: "array", items: Schema::STRING, description: "the text of each part, in order" },
          deliveries: Schema.list(SocialDelivery.reference).merge(description: "one for each target, in order"),
        },
      ).freeze

      attributes :id, :status, :post_id, :targets, :posted_at, :created_at, :updated_at, :parts, :deliveries

      def created_at(social_post) = stamp(social_post.created_at)

      def deliveries(social_post)
        entries = social_post.targets.map do |network|
          found = social_post.deliveries.find { it.network == network }
          SocialDelivery::Entry.new(network:, delivery: found, part_count: social_post.parts.length)
        end
        SocialDelivery.new(entries).serializable_hash
      end

      def parts(social_post) = social_post.parts.map(&:body)

      def posted_at(social_post) = stamp(social_post.posted_at)

      def targets(social_post) = social_post.targets.to_a

      def updated_at(social_post) = stamp(social_post.updated_at)
    end
  end
end
