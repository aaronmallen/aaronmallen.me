# frozen_string_literal: true

module Public
  module Actions
    module Posts
      class Show < Action
        include Deps[
          counted_webmentions_for_post: "social.queries.counted_webmentions_for_post",
          listed_webmentions_for_post: "social.queries.listed_webmentions_for_post",
          next_published_post: "posts.queries.next_published",
          previous_published_post: "posts.queries.previous_published",
          published_post_by_slug: "posts.queries.published_by_slug",
          syndication_urls: "social.queries.syndication_urls",
        ]

        def handle(request, response)
          slug = Blog::Types::Slug.call(path_param(request, :slug)) { not_found(response) }
          post = published_post_by_slug.call(slug)
          not_found(response) unless post

          response[:post] = post
          response[:syndication_urls] = syndication_urls.call(post.id)
          response[:webmentions] = webmentions_for(post)
          expose_body(response, post)
          expose_pager(response, post)
        end

        private

        def expose_body(response, post)
          response[:body_html] = ::Posts::Markdown.to_html(post.body)
        end

        def expose_pager(response, post)
          response[:previous_post] = previous_published_post.call(post)
          response[:next_post] = next_published_post.call(post)
        end

        def webmentions_for(post)
          { responses: listed_webmentions_for_post.call(post.id), counts: counted_webmentions_for_post.call(post.id) }
        end
      end
    end
  end
end
