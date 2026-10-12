# frozen_string_literal: true

module Admin
  module Actions
    module Webmentions
      class Menu < Action
        include Deps[webmention_queries: "social.repos.webmention_queries"]

        def handle(request, response)
          mention = webmention_queries.by_id(record_id(request)) || halt(404)

          response.render(view, mention:, return_to: back_here(request))
        end
      end
    end
  end
end
