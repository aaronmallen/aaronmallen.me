# frozen_string_literal: true

module Record
  module Queries
    class CommitsToday
      include Deps[commit_repo: "repos.commit_repo"]

      def call(now: Time.now) = commit_repo.today(now:)
    end
  end
end
