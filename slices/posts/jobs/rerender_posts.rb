# frozen_string_literal: true

module Posts
  module Jobs
    class RerenderPosts < Blog::ScheduledJob
      include Deps[post_mutations: "repos.post_mutations"]

      def perform = post_mutations.rerender
    end
  end
end
