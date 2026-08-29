# frozen_string_literal: true

module Social
  module Operations
    class DeliverSocialPost < Blog::Operation
      NO_CREDENTIALS = :no_credentials
      OVER_LIMIT = :over_limit
      SEND_FAILED = :send_failed

      include Deps[networks: "networks.all", social_post_repo: "repos.social_post_repo"]

      operate_on :call, :give_up

      def call(social_post_id, network)
        social_post = step targeted(social_post_id, network)
        client = networks.fetch(network)
        step available(social_post, network, client)
        step within_limits(social_post, network, client)
        delivery = social_post_repo.record_delivery(social_post.id, network, error: nil, failed: false)

        step send_parts(social_post, network, client, delivery)
      end

      def give_up(social_post_id, network)
        step found(social_post_id)

        transaction do
          social_post_repo.record_delivery(social_post_id, network, failed: true)
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

      def found(social_post_id)
        social_post = social_post_repo.by_id(social_post_id)

        social_post ? Success(social_post) : Failure(:not_found)
      end

      def idempotency_key(social_post, network, position) = "social-post-#{social_post.id}-#{network}-#{position}"

      def refuse(social_post, network, reason, error)
        transaction do
          social_post_repo.record_delivery(social_post.id, network, error:, failed: true)
          settle(social_post.id)
        end

        Failure(reason)
      end

      def send_part(social_post, network, client, delivery, part)
        remote = client.post(part.body, reply_to: delivery.remote_ids.last,
                                        idempotency_key: idempotency_key(social_post, network, part.position))

        social_post_repo.record_delivery(
          social_post.id, network,
          remote_ids: delivery.remote_ids.to_a + [remote.id],
          remote_url: delivery.remote_url || web_url(remote),
        )
      end

      def send_parts(social_post, network, client, delivery)
        social_post.parts.drop(delivery.remote_ids.size).each do |part|
          delivery = send_part(social_post, network, client, delivery, part)
        end

        Success(settle(social_post.id))
      rescue Social::Error => e
        social_post_repo.record_delivery(social_post.id, network, error: e.message)
        Failure(SEND_FAILED)
      end

      def settle(social_post_id)
        social_post = social_post_repo.by_id(social_post_id)
        return social_post unless settled?(social_post)

        social_post_repo.mark_posted(social_post_id) || social_post
      end

      def settled?(social_post)
        deliveries = social_post.deliveries.to_h { [it.network, it] }

        social_post.targets.all? { done?(deliveries[it], social_post.parts.size) }
      end

      def targeted(social_post_id, network)
        social_post = social_post_repo.by_id(social_post_id)
        return Failure(:not_found) unless social_post
        return Failure(:not_targeted) unless social_post.targets.include?(network)

        Success(social_post)
      end

      def web_url(remote)
        url = remote.url.to_s.strip

        url.empty? ? nil : url
      end

      def within_limits(social_post, network, client)
        over = social_post.parts.find { !client.within_limit?(it.body) }
        return Success(social_post) unless over

        refuse(social_post, network, OVER_LIMIT, "Part #{over.position} is over the #{network} limit")
      end
    end
  end
end
