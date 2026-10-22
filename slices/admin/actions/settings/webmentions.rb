# frozen_string_literal: true

module Admin
  module Actions
    module Settings
      class Webmentions < Action
        include Deps[
          build_person_editor: "operations.build_person_editor",
          build_settings_tabs: "operations.build_settings_tabs",
          networks: "social_networks.all",
          person_queries: "contacts.repos.person_queries",
          post_queries: "posts.repos.post_queries",
          webmention_queries: "social.repos.webmention_queries",
        ]

        def handle(_request, response)
          response.render(
            view,
            people: { people: person_queries.all, editor: build_person_editor.call, searchable: },
            webmentions: {
              posts: post_queries.summaries, settings: webmention_queries.settings,
              trusted: webmention_queries.trusted,
            },
            tabs: build_settings_tabs.call,
          )
        end

        private

        def searchable
          Blog::Types::NetworkName.values.select { networks.fetch(it).then { it.respond_to?(:search) && it.configured? } }
        end
      end
    end
  end
end
