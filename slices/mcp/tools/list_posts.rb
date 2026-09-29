# frozen_string_literal: true

require "time"

module MCP
  module Tools
    class ListPosts < Base
      DRAFT = Blog::Types::PostStatus["draft"]
      PREVIEW_LENGTH = 120

      SCHEMA = {
        additionalProperties: false,
        properties: {
          from: { type: "string", description: "the first day a blog post's publish time may fall on, as YYYY-MM-DD" },
          page: Paging::PAGE,
          to: { type: "string", description: "the last day a blog post's publish time may fall on, as YYYY-MM-DD" },
        },
      }.freeze

      description "List every blog post, in any status, and every social post that has not been sent yet. " \
                  "Each blog post says whether it is a draft and when it goes out or went out. " \
                  "Give from, to or both as YYYY-MM-DD, in Chicago time, to keep only the blog posts whose " \
                  "publish time falls inside those days; a post with no publish time then drops out. " \
                  "The range leaves the social posts alone. Both lists page together: page 2 holds the second " \
                  "page of each. #{Paging::USAGE}"
      input_schema(SCHEMA)
      scope OAuth::Scope::READ

      class << self
        def call(server_context:, page: 1, **range)
          days = range.transform_values { Blog::TimeZone.parse_day(it) }
          return refuse("give from and to as days, such as 2026-01-01") if days.value?(nil)
          return refuse("from comes after to") if backwards?(days)

          listed(days, page(page, server_context), server_context)
        end

        private

        def backwards?(days)
          first, last = days.values_at(:from, :to)

          first && last && first > last
        end

        def first_words(social_post)
          body = Blog::Whitespace.squish(social_post.parts.first&.body)

          Blog::Truncation.cut(body, keep: PREVIEW_LENGTH)
        end

        def listed(days, page, server_context)
          posts = dated_posts(server_context).call(from: days[:from], to: days[:to], page:)
          social_posts = unsent_social_posts(server_context).call(page)

          answer(
            posts: posts.rows.map { summary(it) },
            social_posts: social_posts.rows.map { preview(it) },
            **Paging.fields(posts, social_posts),
          )
        end

        def preview(social_post)
          { id: social_post.id, preview: first_words(social_post), status: social_post.status }
        end

        def summary(post)
          {
            id: post.id,
            draft: post.status == DRAFT,
            published_at: post.published_at&.utc&.iso8601,
            status: post.status,
            title: post.title,
            updated_at: post.updated_at.utc.iso8601,
          }
        end
      end
    end
  end
end
