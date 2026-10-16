# frozen_string_literal: true

module Social
  module Operations
    class DeliverSocialPost < Blog::Operation
      FINAL = [LinkedIn::Expired, LinkedIn::Unsure].freeze
      GAVE_UP = :gave_up
      OVER_LIMIT = :over_limit
      SCHEDULED = Blog::Types::SocialPostStatus["scheduled"]
      SEND_FAILED = :send_failed

      include Deps[
        expand_for_network: "operations.expand_for_network",
        list_target_accounts: "operations.list_target_accounts",
        networks: "networks.all",
        read_photo: "media.operations.read_photo",
        social_post_mutations: "repos.social_post_mutations",
        social_post_queries: "repos.social_post_queries",
      ]

      operate_on :call, :give_up

      def call(social_post_id, connection_id)
        social_post, account = step targeted(social_post_id, connection_id)
        client = client_for(social_post, account)
        bodies = expanded(social_post, account.provider)
        step within_limits(social_post, account, client, bodies)
        delivery = social_post_mutations.record_delivery(social_post.id, account, error: nil, failed: false)

        step send_parts(social_post, account, client, delivery, bodies)
      end

      def give_up(social_post_id, connection_id, error = nil)
        social_post = step found(social_post_queries.by_id(social_post_id))
        account = list_target_accounts.call(social_post).find { it.id == connection_id }
        error = delivery_for(social_post, connection_id)&.error || error

        transaction do
          social_post_mutations.record_delivery(social_post_id, account, error:, failed: true) if account
          settle(social_post_id)
        end
      end

      private

      def client_for(social_post, account)
        client = networks.fetch(account.provider).for(account)
        retrying = (delivery = delivery_for(social_post, account.id)) && delivery.updated_at > delivery.created_at

        retrying && client.respond_to?(:retrying) ? client.retrying : client
      end

      def delivery_for(social_post, connection_id) = social_post.deliveries.find { it.connection_id == connection_id }

      def done?(social_post, account)
        return false unless (delivery = delivery_for(social_post, account.id))

        delivery.failed || delivery.remote_ids.to_a.size >= sends(account, social_post)
      end

      def due?(social_post) = social_post.status == SCHEDULED && social_post.posted_at <= Time.now

      def expanded(social_post, network)
        expand_for_network.call(social_post.parts.map(&:body), network, make_links: true)
      end

      def held_photos(parts)
        held = social_post_queries.photos_by_part(parts.map(&:id))

        parts.map { held.fetch(it.id, Blog::Constants::EMPTY_ARRAY) }
      end

      def photos(held)
        held.map do |row|
          read = read_photo.call(row.photo_key).value_or { raise Social::Error, "Photo #{row.photo_key} is unavailable" }

          Structs::PartPhoto.new(
            alt: row.alt_text, body: read.stored.body, content_type: read.stored.content_type,
            height: read.photo.height, width: read.photo.width,
          )
        end
      end

      def refuse(social_post, account, reason, error)
        transaction do
          social_post_mutations.record_delivery(social_post.id, account, error:, failed: true)
          settle(social_post.id)
        end

        Failure(reason)
      end

      def send_part(social_post, account, client, delivery, (part, body, held))
        remote = client.post(body.text, mentions: body.mentions, photos: photos(held),
                                        reply_to: delivery.remote_ids.last,
                                        idempotency_key: Structs::PartKey.new(connection_id: account.id, part:))

        social_post_mutations.record_delivery(
          social_post.id, account,
          remote_ids: delivery.remote_ids.to_a + [remote.id],
          remote_url: delivery.remote_url || web_url(remote),
        )
      end

      def send_parts(social_post, account, client, delivery, bodies)
        sendings(social_post, bodies).drop(delivery.remote_ids.size).each do |sending|
          delivery = send_part(social_post, account, client, delivery, sending)
        end

        Success(settle(social_post.id))
      rescue *FINAL => e
        refuse(social_post, account, GAVE_UP, e.message)
      rescue Blog::ServiceError => e
        social_post_mutations.record_delivery(social_post.id, account, error: e.message)
        Failure(SEND_FAILED)
      end

      def sendings(social_post, bodies)
        held = held_photos(social_post.parts)
        return social_post.parts.zip(bodies, held) if bodies.size == social_post.parts.size

        [[social_post.parts.first, bodies.first, held.flatten]]
      end

      def sends(account, social_post) = networks.fetch(account.provider).joiner ? 1 : social_post.parts.size

      def settle(social_post_id)
        social_post = social_post_queries.by_id(social_post_id)
        accounts = list_target_accounts.call(social_post)
        return social_post unless settled?(social_post, accounts)

        social_post_mutations.mark_sent(social_post, accounts) || social_post
      end

      def settled?(social_post, accounts) = accounts.all? { done?(social_post, it) }

      def targeted(social_post_id, connection_id)
        found(social_post_queries.by_id(social_post_id)).bind do |social_post|
          next Failure(:not_due) unless due?(social_post)

          account = list_target_accounts.call(social_post).find { it.id == connection_id }
          account ? Success([social_post, account]) : Failure(:not_targeted)
        end
      end

      def web_url(remote)
        url = remote.url.to_s.strip

        url.empty? ? nil : url
      end

      def within_limits(social_post, account, client, bodies)
        over = bodies.index { !client.within_limit?(it.text) }
        return Success(social_post) unless over

        refuse(social_post, account, OVER_LIMIT, "Part #{over + 1} is over the #{account.provider} limit")
      end
    end
  end
end
