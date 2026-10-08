# frozen_string_literal: true

module Social
  module Operations
    class DeliverSocialPost < Operation
      NO_CREDENTIALS = :no_credentials
      OVER_LIMIT = :over_limit
      SCHEDULED = Blog::Types::SocialPostStatus["scheduled"]
      SEND_FAILED = :send_failed

      include Deps[
        expand_for_network: "operations.expand_for_network",
        networks: "networks.all",
        social_post_mutations: "repos.social_post_mutations",
        social_post_queries: "repos.social_post_queries",
      ]

      operate_on :call, :give_up

      def call(social_post_id, network)
        social_post = step targeted(social_post_id, network)
        client = networks.fetch(network)
        step available(social_post, network, client)
        bodies = expanded(social_post, network)
        step within_limits(social_post, network, client, bodies)
        delivery = social_post_mutations.record_delivery(social_post.id, network, error: nil, failed: false)

        step send_parts(social_post, network, client, delivery, bodies)
      end

      def give_up(social_post_id, network)
        step found(social_post_queries.by_id(social_post_id))

        transaction do
          social_post_mutations.record_delivery(social_post_id, network, failed: true)
          settle(social_post_id)
        end
      end

      private

      def available(social_post, network, client)
        return Success(social_post) if client.configured?

        refuse(social_post, network, NO_CREDENTIALS, "#{network} has no credentials")
      end

      def done?(delivery, parts)
        return false unless delivery

        delivery.failed || delivery.remote_ids.to_a.size >= parts
      end

      def due?(social_post) = social_post.status == SCHEDULED && social_post.posted_at <= Time.now

      def expanded(social_post, network) = expand_for_network.call(social_post.parts.map(&:body), network)

      def refuse(social_post, network, reason, error)
        transaction do
          social_post_mutations.record_delivery(social_post.id, network, error:, failed: true)
          settle(social_post.id)
        end

        Failure(reason)
      end

      def send_part(social_post, network, client, delivery, (part, body))
        remote = client.post(body.text, mentions: body.mentions, reply_to: delivery.remote_ids.last,
                                        idempotency_key: Structs::PartKey.new(network:, part:))

        social_post_mutations.record_delivery(
          social_post.id, network,
          remote_ids: delivery.remote_ids.to_a + [remote.id],
          remote_url: delivery.remote_url || web_url(remote),
        )
      end

      def send_parts(social_post, network, client, delivery, bodies)
        social_post.parts.zip(bodies).drop(delivery.remote_ids.size).each do |sending|
          delivery = send_part(social_post, network, client, delivery, sending)
        end

        Success(settle(social_post.id))
      rescue Social::Error => e
        social_post_mutations.record_delivery(social_post.id, network, error: e.message)
        Failure(SEND_FAILED)
      end

      def settle(social_post_id)
        social_post = social_post_queries.by_id(social_post_id)
        return social_post unless settled?(social_post)

        social_post_mutations.mark_posted(social_post_id) || social_post
      end

      def settled?(social_post)
        deliveries = social_post.deliveries.to_h { [it.network, it] }

        social_post.targets.all? { done?(deliveries[it], social_post.parts.size) }
      end

      def targeted(social_post_id, network)
        found(social_post_queries.by_id(social_post_id)).bind do |social_post|
          next Failure(:not_due) unless due?(social_post)
          next Failure(:not_targeted) unless social_post.targets.include?(network)

          Success(social_post)
        end
      end

      def web_url(remote)
        url = remote.url.to_s.strip

        url.empty? ? nil : url
      end

      def within_limits(social_post, network, client, bodies)
        over = social_post.parts.zip(bodies).find { |_, body| !client.within_limit?(body.text) }&.first
        return Success(social_post) unless over

        refuse(social_post, network, OVER_LIMIT, "Part #{over.position} is over the #{network} limit")
      end
    end
  end
end
