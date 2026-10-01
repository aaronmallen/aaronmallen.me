# frozen_string_literal: true

module Posts
  module Operations
    class SavePostSeo < Blog::Operation
      include Deps[
        claim_photos: "media.operations.claim_photos",
        contract: "contracts.post_seo_contract",
        post_repo: "repos.post_repo",
      ]

      FIELDS = %i[canonical_url og_image_url og_title].freeze
      PHOTO_OWNER = Blog::Types::PhotoOwner["post"]

      def call(id, params)
        transaction do
          post = step find(id)
          saved = post_repo.update(id, step(validate(post, params)))
          claim_photos.call(PHOTO_OWNER, id, saved.body, saved.og_image_url)
        end

        post_repo.by_id(id)
      end

      private

      def find(id)
        post = post_repo.by_id_for_update(id)

        post ? Success(post) : Failure(:not_found)
      end

      def given(post, params) = FIELDS.to_h { [it, params.key?(it) ? params[it] : post.public_send(it).to_s] }

      def validate(post, params) = validated(contract.call(given(post, params)))
    end
  end
end
