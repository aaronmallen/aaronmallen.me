# frozen_string_literal: true

module Social
  module Relations
    class SocialPostDeliveries < Blog::DB::Relation
      POSTED = Blog::Types::SocialPostStatus["posted"]

      schema :social_post_deliveries, infer: true do
        associations do
          belongs_to :social_post
        end
      end

      def claim(social_post_id:, network:, stale_before:)
        reclaim = command(:record).with(update_statement: excluded(%i[updated_at]), update_where: stalled(stale_before))

        reclaim.call(social_post_id:, network:)
      end

      def for_social_post(social_post_id) = where(social_post_id:)

      def in_network_order = order(self[:network].asc)

      def record(social_post_id:, network:, **attrs)
        update_statement = excluded([*attrs.keys, :updated_at])

        command(:record).with(update_statement:).call(social_post_id:, network:, **attrs)
      end

      def syndicated_for_post(post_id)
        network = self[:network].qualified
        oldest = %i[posted_at id].map { social_posts[it].qualified.asc }
        sent = delivered_for_post(post_id).distinct(network).order(network, *oldest)

        sent.select(network, self[:remote_url].qualified)
      end

      private

      def delivered_for_post(post_id)
        posted = { social_posts[:post_id].qualified => post_id, social_posts[:status].qualified => POSTED }

        unordered.join(:social_post).where(posted).exclude(self[:remote_url].qualified => nil)
      end

      def stalled(stale_before)
        idle = self[:updated_at].qualified < stale_before

        Sequel.&(idle, { self[:error].qualified => nil, self[:failed].qualified => false })
      end
    end
  end
end
