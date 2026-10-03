# frozen_string_literal: true

module Social
  module Queries
    class CalendarSocialPosts
      include Deps[social_post_repo: "repos.social_post_repo"]

      def call(from:, to:) = social_post_repo.calendar_between(from:, to:)
    end
  end
end
