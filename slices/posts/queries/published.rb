# frozen_string_literal: true

module Posts
  module Queries
    class Published
      include Deps[post_repo: "repos.post_repo"]

      def call = post_repo.published
    end
  end
end
