# frozen_string_literal: true

module Posts
  module Queries
    class All
      include Deps[post_repo: "repos.post_repo"]

      def call = post_repo.all
    end
  end
end
