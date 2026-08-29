# frozen_string_literal: true

module Social
  module Operations
    class SaveSocialPost < Blog::Operation
      include Deps[contract: "contracts.social_post_contract", social_post_repo: "repos.social_post_repo"]

      def call(id: nil, **attrs)
        attributes = step validate(attrs)

        step written(persist(id, attributes))
      end

      private

      def persist(id, attributes)
        return social_post_repo.create_with_parts(**attributes) unless id

        social_post_repo.update_with_parts(id, **attributes)
      end

      def validate(attrs) = validated(contract.call(attrs))

      def written(saved) = saved ? Success(saved) : Failure(:already_posted)
    end
  end
end
