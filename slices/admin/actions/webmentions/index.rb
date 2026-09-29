# frozen_string_literal: true

module Admin
  module Actions
    module Webmentions
      class Index < Action
        include Deps[
          "settings",
          all_posts: "posts.queries.all",
          webmention_counts_by_status: "social.queries.webmention_counts_by_status",
          webmention_settings: "social.queries.webmention_settings",
          webmentions_by_status: "social.queries.webmentions_by_status",
        ]

        def handle(request, response)
          filter = Blog::Types::WebmentionStatusParam[request.params[:status]]
          mentions = webmentions_by_status.call(filter, requested_page(request, response, settings.page_size[:admin]))
          not_found(response) if mentions.past_end?

          response.render(view, **exposures(filter, mentions))
        end

        private

        def exposures(filter, mentions)
          posts = all_posts.call

          {
            counts: webmention_counts_by_status.call,
            filter:,
            inbox: { mentions:, slugs: posts.to_h { [it.id, it.slug] } },
            posts:,
            settings: webmention_settings.call,
          }
        end
      end
    end
  end
end
