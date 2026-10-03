# frozen_string_literal: true

module Posts
  module Queries
    class CalendarPosts
      include Deps[post_repo: "repos.post_repo"]

      def call(from:, to:) = post_repo.calendar_between(from:, to:)
    end
  end
end
