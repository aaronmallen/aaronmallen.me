# frozen_string_literal: true

module Admin
  module Actions
    module Webmentions
      class Index < Action
        include Deps[
          all_posts: "posts.queries.all",
          webmention_counts_by_status: "social.queries.webmention_counts_by_status",
          webmention_settings: "social.queries.webmention_settings",
          webmentions_by_status: "social.queries.webmentions_by_status",
        ]

        def handle(request, response)
          response.render(view, **exposures(request))
        end

        private

        def exposures(request)
          filter = Blog::Types::WebmentionStatusParam[request.params[:status]]
          posts = all_posts.call

          {
            counts: webmention_counts_by_status.call,
            filter:,
            inbox: { mentions: webmentions_by_status.call(filter), slugs: posts.to_h { [it.id, it.slug] } },
            posts:,
            settings: webmention_settings.call,
          }
        end
      end
    end
  end
end
