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
          page: Blog::Paging::PAGE,
          status: { type: "string", enum: Blog::Types::PostStatus.values, description: "keep only blog posts in it" },
          to: { type: "string", description: "the last day a blog post's publish time may fall on, as YYYY-MM-DD" },
        },
      }.freeze

      description "List every blog post, in any status, and every social post that has not been sent yet. " \
                  "Each blog post gives its slug and tags, says whether it is a draft and when it goes out or " \
                  "went out, and gives its word count, its views, visitors and read-throughs over the last 90 " \
                  "days, its unique readers (null for a post that went out too long before the site began " \
                  "counting) and the webmentions it received. Give status to keep only the blog posts in it. " \
                  "counts gives how many blog posts in the range sit in each status, whatever status asks for. " \
                  "Give from, to or both as YYYY-MM-DD, in Chicago time, to keep only the blog posts whose " \
                  "publish time falls inside those days; a post with no publish time then drops out. " \
                  "The range leaves the social posts alone. Both lists page together: page 2 holds the second " \
                  "page of each. #{Blog::Paging::USAGE}"
      input_schema(SCHEMA)
      scope OAuth::Scope::READ

      class << self
        def call(server_context:, page: 1, status: nil, **range)
          case Blog::DayWindow.open_days(range[:from], range[:to])
          in Success[first, last] then listed(first, last, status, page(page, server_context), server_context)
          in Failure(message) then refuse(message)
          end
        end

        private

        def first_words(social_post)
          body = Blog::Whitespace.squish(social_post.parts.first&.body)

          Blog::Truncation.cut(body, keep: PREVIEW_LENGTH)
        end

        def listed(first, last, status, page, server_context)
          posts = dep(:dated_posts, server_context).call(from: first, to: last, page:, status:)
          social_posts = dep(:unsent_social_posts, server_context).call(page)

          answer(
            counts: dep(:dated_post_counts, server_context).call(from: first, to: last),
            posts: summaries(posts.rows, server_context),
            social_posts: social_posts.rows.map { preview(it) },
            **Blog::Paging.fields(posts, social_posts),
          )
        end

        def preview(social_post)
          { id: social_post.id, preview: first_words(social_post), status: social_post.status }
        end

        def summaries(posts, server_context)
          figures = dep(:post_figures, server_context).call(posts)

          posts.map { summary(it, figures) }
        end

        def summary(post, figures)
          {
            id: post.id,
            draft: post.status == DRAFT,
            published_at: post.published_at&.utc&.iso8601,
            slug: post.slug,
            status: post.status,
            tags: post.tags.map(&:name),
            title: post.title,
            updated_at: post.updated_at.utc.iso8601,
            **tally(post.id, figures),
          }
        end

        def tally(id, figures)
          {
            word_count: figures.fetch(:word_counts).fetch(id),
            views: figures.fetch(:view_counts).fetch(id),
            visitors: figures.fetch(:visitor_counts).fetch(id),
            readers: figures.fetch(:unique_reader_counts).fetch(id).fetch(:readers),
            read_throughs: figures.fetch(:read_through_counts).fetch(id),
            webmentions_received: figures.fetch(:webmention_counts).fetch(id, 0),
          }
        end
      end
    end
  end
end
