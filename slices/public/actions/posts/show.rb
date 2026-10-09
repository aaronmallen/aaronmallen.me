# frozen_string_literal: true

module Public
  module Actions
    module Posts
      class Show < Action
        include Deps[
          photo_queries: "media.repos.photo_queries",
          post_queries: "posts.repos.post_queries",
          social_post_queries: "social.repos.social_post_queries",
          webmention_queries: "social.repos.webmention_queries",
        ]

        share_with_caches

        def handle(request, response)
          slug = Blog::Types::Slug.call(path_param(request, :slug)) { not_found(response) }
          post = post_queries.published_by_slug(slug)
          not_found(response) unless post

          response[:post] = post
          response[:syndication_urls] = social_post_queries.syndication_urls(post.id)
          response[:webmentions] = webmentions_for(post)
          expose_body(response, post)
          expose_pager(response, post)
        end

        private

        def expose_body(response, post)
          response[:body_html] = ::Posts::Markdown.size_images(post.body_html) { photo_queries.sizes(it) }
          response[:headings] = post.headings
          response[:edits] = post_queries.edits_for_post(post.id)
        end

        def expose_pager(response, post)
          response[:previous_post] = post_queries.previous_published(post)
          response[:next_post] = post_queries.next_published(post)
        end

        def webmentions_for(post)
          { responses: webmention_queries.listed_for(post.id), counts: webmention_queries.counted_for(post.id) }
        end
      end
    end
  end
end
