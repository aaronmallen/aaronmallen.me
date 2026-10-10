# frozen_string_literal: true

module Posts
  module Operations
    class SavePostSeo < Blog::Operation
      include Deps[
        claim_post_photos: "operations.claim_post_photos",
        contract: "contracts.post_seo_contract",
        post_mutations: "repos.post_mutations",
        post_queries: "repos.post_queries",
      ]

      FIELDS = %i[canonical_url og_image_url og_title].freeze

      def call(id, params)
        transaction do
          post = step find(id)
          claim_post_photos.call(post_mutations.update(id, step(validate(post, params))))
        end

        post_queries.by_id(id)
      end

      private

      def find(id)
        found(post_mutations.by_id_for_update(id))
      end

      def given(post, params) = FIELDS.to_h { [it, params.key?(it) ? params[it] : post.public_send(it).to_s] }

      def validate(post, params) = validated(contract.call(given(post, params)))
    end
  end
end
