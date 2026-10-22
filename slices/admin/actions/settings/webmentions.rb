# frozen_string_literal: true

module Admin
  module Actions
    module Settings
      class Webmentions < Action
        include Deps[
          build_settings_tabs: "operations.build_settings_tabs",
          post_queries: "posts.repos.post_queries",
          webmention_queries: "social.repos.webmention_queries",
        ]

        def handle(_request, response)
          response.render(
            view,
            webmentions: {
              posts: post_queries.summaries, settings: webmention_queries.settings,
              trusted: webmention_queries.trusted,
            },
            tabs: build_settings_tabs.call,
          )
        end
      end
    end
  end
end
