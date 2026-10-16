# frozen_string_literal: true

module Admin
  module Actions
    module Webmentions
      class Settings < Action
        include Deps[
          post_queries: "posts.repos.post_queries",
          webmention_queries: "social.repos.webmention_queries",
        ]

        def handle(_request, response)
          response.render(
            view,
            posts: post_queries.summaries, settings: webmention_queries.settings, trusted: webmention_queries.trusted,
          )
        end
      end
    end
  end
end
