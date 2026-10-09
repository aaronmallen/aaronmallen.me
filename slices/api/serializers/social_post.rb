# frozen_string_literal: true

module API
  module Serializers
    class SocialPost < Serializer
      DELIVERIES = "one for each account it goes to, by target in order, or one with no account for a bare target"
      LENGTH = Helpers::Schema.object({ count: Helpers::Schema::INTEGER, limit: Helpers::Schema::INTEGER })
      POSTED = Blog::Types::SocialPostStatus["posted"]
      LENGTHS = "for each part in order, its length on each network it targets, counted the way send counts"
      NETWORKS = Blog::Types::NetworkName.values.to_h { [it.to_sym, LENGTH] }

      SCHEMA = Helpers::Schema.object(
        {
          id: Helpers::Schema::INTEGER,
          status: { type: "string", enum: Blog::Types::SocialPostStatus.values },
          post_id: Helpers::Schema.nullable(Helpers::Schema::INTEGER),
          targets: Helpers::Schema.list({ type: "string", enum: Blog::Types::NetworkName.values }),
          posted_at: Helpers::Schema.nullable(Helpers::Schema::STAMP),
          created_at: Helpers::Schema::STAMP,
          updated_at: Helpers::Schema::STAMP,
          parts: { type: "array", items: Helpers::Schema::STRING, description: "the text of each part, in order" },
          deliveries: Helpers::Schema.list(SocialDelivery.reference).merge(
            description: DELIVERIES,
          ),
        },
        optional: {
          lengths: Helpers::Schema.list(Helpers::Schema.object({}, optional: NETWORKS)).merge(description: LENGTHS),
        },
      ).freeze

      schema_attributes
      attributes :lengths, if: :measured?
      stamps :created_at, :posted_at, :updated_at

      def deliveries(social_post)
        accounts = params[:target_accounts]&.call(social_post).to_a
        entries = social_post.targets.flat_map { delivered_on(social_post, it, accounts) }

        SocialDelivery.new(entries).serializable_hash
      end

      def lengths(social_post)
        measured = params.fetch(:measure_parts).call(parts(social_post), targets(social_post))

        measured.map { |part| part.transform_values(&:counted) }
      end

      def parts(social_post) = social_post.parts.map(&:body)

      def targets(social_post) = social_post.targets.to_a

      private

      def delivered_on(social_post, network, accounts)
        rows = social_post.deliveries.select { it.network == network }
        found = named(social_post, rows, accounts.select { it.provider == network }) + unnamed(rows, accounts)

        (found.empty? ? [[nil, nil]] : found).map do |account, delivery|
          SocialDelivery::Entry.new(network:, account:, delivery:, part_count: social_post.parts.length)
        end
      end

      def measured? = params.key?(:measure_parts)

      def named(social_post, rows, accounts)
        waiting = social_post.status != POSTED && rows.all?(&:connection_id)

        accounts.filter_map do |account|
          row = rows.find { it.connection_id == account.id }
          [account.label, row] if row || waiting
        end
      end

      def unnamed(rows, accounts) = rows.reject { |row| accounts.any? { it.id == row.connection_id } }.map { [nil, it] }
    end
  end
end
