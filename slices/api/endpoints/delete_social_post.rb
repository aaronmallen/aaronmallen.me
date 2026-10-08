# frozen_string_literal: true

module API
  module Endpoints
    class DeleteSocialPost < SocialPostEndpoint
      SCHEMA = Helpers::Schema.by_id
      REPLY = Helpers::Schema.object({ id: Helpers::Schema::INTEGER, deleted: Helpers::Schema::BOOLEAN }).freeze

      include Deps[delete_social_post: "social.operations.delete_social_post"]

      def handle(id:)
        case delete_social_post.call(id)
          in Success(_) then Success(id:, deleted: true)
          in Failure(:already_posted) then gone(id, "removed")
          in Failure(:not_found) then not_found(Helpers::Wording.missing("social post", id))
          else failed("could not delete the social post")
        end
      end
    end
  end
end
