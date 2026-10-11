# frozen_string_literal: true

module Social
  module Operations
    class SaveSocialPost < Blog::Operation
      include Deps[
        claim_part_photos: "operations.claim_part_photos",
        contract: "contracts.social_post_contract",
        social_post_mutations: "repos.social_post_mutations",
        social_post_queries: "repos.social_post_queries",
      ]

      def call(id: nil, **attrs)
        attributes = step validate(attrs)

        step written(persist(id, attributes))
      end

      private

      def persist(id, attributes)
        transaction do
          held = id ? social_post_queries.part_photo_keys(id).keys : Blog::Constants::EMPTY_ARRAY
          saved = write(id, attributes)
          claim_part_photos.call(saved.id, held) if saved
          saved
        end
      end

      def validate(attrs) = validated(contract.call(attrs))

      def write(id, attributes)
        return social_post_mutations.create_with_parts(**attributes) unless id

        social_post_mutations.update_with_parts(id, **attributes)
      end

      def written(saved) = saved ? Success(saved) : Failure(:already_posted)
    end
  end
end
