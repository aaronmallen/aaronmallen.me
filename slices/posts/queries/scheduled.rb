# frozen_string_literal: true

module Posts
  module Queries
    class Scheduled
      include Deps[post_repo: "repos.post_repo"]

      def call = post_repo.scheduled
    end
  end
end
