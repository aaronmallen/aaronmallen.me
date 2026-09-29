# frozen_string_literal: true

module Record
  module Queries
    class CommitsToday
      include Deps[commit_repo: "repos.commit_repo"]

      def call(now: Time.now, limit: nil) = commit_repo.today(now:, limit:)
    end
  end
end
