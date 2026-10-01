# frozen_string_literal: true

module Posts
  module Queries
    class Summaries
      include Deps[post_repo: "repos.post_repo"]

      def call = post_repo.summaries
    end
  end
end
