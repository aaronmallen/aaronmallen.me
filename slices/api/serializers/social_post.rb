# frozen_string_literal: true

module API
  module Serializers
    class SocialPost < Serializer
      LENGTH = Schema.object({ count: Schema::INTEGER, limit: Schema::INTEGER })
      LENGTHS = "for each part in order, its length on each network it targets, counted the way send counts"
      NETWORKS = Blog::Types::NetworkName.values.to_h { [it.to_sym, LENGTH] }

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
        optional: { lengths: Schema.list(Schema.object({}, optional: NETWORKS)).merge(description: LENGTHS) },
      ).freeze

      schema_attributes
      attributes :lengths, if: :measured?
      stamps :created_at, :posted_at, :updated_at

      def deliveries(social_post)
        entries = social_post.targets.map do |network|
          found = social_post.deliveries.find { it.network == network }
          SocialDelivery::Entry.new(network:, delivery: found, part_count: social_post.parts.length)
        end
        SocialDelivery.new(entries).serializable_hash
      end

      def lengths(social_post)
        measured = params.fetch(:measure_parts).call(parts(social_post), targets(social_post))

        measured.map { |part| part.transform_values(&:counted) }
      end

      def parts(social_post) = social_post.parts.map(&:body)

      def targets(social_post) = social_post.targets.to_a

      private

      def measured? = params.key?(:measure_parts)
    end
  end
end
