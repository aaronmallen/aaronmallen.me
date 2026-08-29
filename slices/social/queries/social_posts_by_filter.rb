# frozen_string_literal: true

module Social
  module Queries
    class SocialPostsByFilter
      DRAFTS = Blog::Types::SocialQueue["drafts"]
      POSTED = Blog::Types::SocialQueue["posted"]

      include Deps[social_post_repo: "repos.social_post_repo"]

      def call(filter)
        case Blog::Types::SocialQueue[filter]
        when DRAFTS then social_post_repo.drafts
        when POSTED then social_post_repo.posted
        else social_post_repo.queued
        end
      end
    end
  end
end
