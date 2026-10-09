# frozen_string_literal: true

module Social
  module Operations
    class ComposeSocialPost < Operation
      DRAFT = Blog::Types::SocialIntent["draft"]
      DRAFTED = Blog::Types::SocialPostStatus["draft"]
      FIELDS = %i[mode parts schedule_at targets].freeze
      SCHEDULE = Blog::Types::SocialMode["schedule"]
      SCHEDULED = Blog::Types::SocialPostStatus["scheduled"]
      SEND = Blog::Types::SocialIntent["send"]
      UNAVAILABLE = { targets: [Contracts::ComposeSocialPostContract::UNAVAILABLE] }.freeze

      include Deps[
        "services.repos.connection_queries",
        contract: "contracts.compose_social_post_contract",
        save_social_post: "operations.save_social_post",
        social_post_queries: "repos.social_post_queries",
      ]

      def call(params, intent: DRAFT, id: nil, now: Time.now)
        social_post = step editable(id)
        attributes = step validate(params, intent)

        save(attributes, intent, now, social_post)
      end

      private

      def accounts = Blog::Types::NetworkName.values.flat_map { connection_queries.for(it) }

      def disposition(attributes, intent, now)
        return [:drafted, DRAFTED, nil] unless intent == SEND
        return [:queued, SCHEDULED, now] unless attributes[:mode] == SCHEDULE

        [:scheduled, SCHEDULED, attributes[:schedule_at]]
      end

      def editable(id)
        return Success(nil) unless id

        social_post = social_post_queries.editable(id)
        return Success(social_post) if social_post

        social_post_queries.by_id(id) ? Failure(:already_posted) : Failure(:not_found)
      end

      def form(params)
        found = FIELDS.to_h { [it, params[it]] }
        return found unless params.key?(:accounts)

        picked = picked(Array(params[:accounts]).map(&:to_s).reject(&:empty?).uniq)
        picked && found.merge(picked)
      end

      def picked(wanted)
        chosen = accounts.select { wanted.include?(it.id.to_s) }
        return unless chosen.size == wanted.size

        { targets: chosen.map(&:provider).uniq, connection_ids: chosen.map(&:id) }
      end

      def save(attributes, intent, now, social_post)
        fields = attributes.slice(:parts, :targets, :connection_ids)
        outcome, status, posted_at = disposition(attributes, intent, now)

        [outcome, step(save_social_post.call(id: social_post&.id, status:, posted_at:, **fields))]
      end

      def validate(params, intent)
        fields = form(params)

        fields ? validated(contract.call(fields, intent:)) : Failure([:invalid, UNAVAILABLE])
      end
    end
  end
end
