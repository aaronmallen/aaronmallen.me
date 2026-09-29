# frozen_string_literal: true

module Social
  module Queries
    class SocialPostsByFilter
      DRAFTS = Blog::Types::SocialQueue["drafts"]
      POSTED = Blog::Types::SocialQueue["posted"]

      include Deps[social_post_repo: "repos.social_post_repo"]

      def call(filter, page)
        case Blog::Types::SocialQueue[filter]
        when DRAFTS then social_post_repo.drafts_page(page)
        when POSTED then social_post_repo.posted_page(page)
        else social_post_repo.queued_page(page)
        end
      end
    end
  end
end
