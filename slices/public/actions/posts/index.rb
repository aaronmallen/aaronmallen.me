# frozen_string_literal: true

module Public
  module Actions
    module Posts
      class Index < Action
        include Deps[published_posts: "posts.queries.published"]

        def handle(_request, response)
          response[:posts] = published_posts.call
        end
      end
    end
  end
end
