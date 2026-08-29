# frozen_string_literal: true

module Posts
  module Operations
    class SavePostSeo < Blog::Operation
      include Deps[contract: "contracts.post_seo_contract", post_repo: "repos.post_repo"]

      FIELDS = %i[canonical_url og_image_url og_title].freeze

      def call(id, params)
        transaction do
          post = step find(id)
          post_repo.update(id, step(validate(post, params)))
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
