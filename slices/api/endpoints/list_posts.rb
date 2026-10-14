# frozen_string_literal: true

module API
  module Endpoints
    class ListPosts < Endpoint
      DRAFT = Blog::Types::PostStatus["draft"]
      PREVIEW_LENGTH = 120

      SCHEMA = {
        additionalProperties: false,
        properties: {
          from: { type: "string", description: "the first day a blog post's publish time may fall on, as YYYY-MM-DD" },
          page: Blog::Helpers::Paging::PAGE,
          status: { type: "string", enum: Blog::Types::PostStatus.values, description: "keep only blog posts in it" },
          to: { type: "string", description: "the last day a blog post's publish time may fall on, as YYYY-MM-DD" },
        },
      }.freeze

      POST = Helpers::Schema.widen(
        Serializers::Post::SCHEMA,
        draft: Helpers::Schema::BOOLEAN,
        word_count: Helpers::Schema::INTEGER,
        views: Helpers::Schema::INTEGER,
        visitors: Helpers::Schema::INTEGER,
        readers: Helpers::Schema.nullable(
          { type: "integer", description: "null for a post that went out before the site counted readers" },
        ),
        read_throughs: Helpers::Schema::INTEGER,
        webmentions_received: Helpers::Schema::INTEGER,
      ).freeze

      SOCIAL_POST = Helpers::Schema.object(
        {
          id: Helpers::Schema::INTEGER,
          preview: { type: "string", description: "the first words of its first part" },
          status: { type: "string", enum: Blog::Types::SocialPostStatus.values },
        },
      ).freeze

      COUNTS = Helpers::Schema.object(
        Blog::Types::PostStatus.values.to_h { [it.to_sym, Helpers::Schema::INTEGER] },
      ).merge(description: "how many blog posts in the range sit in each status").freeze

      REPLY = Helpers::Schema.paged(
        {
          counts: COUNTS,
          posts: Helpers::Schema.list(POST),
          social_posts: Helpers::Schema.list(SOCIAL_POST),
        },
      ).freeze

      include Deps[
        "repos.post_figure_queries",
        post_queries: "posts.repos.post_queries",
        social_post_queries: "social.repos.social_post_queries",
      ]

      def handle(page: 1, status: nil, **range)
        case Blog::Helpers::DayWindow.open_days(range[:from], range[:to])
          in Success[first, last] then Success(listed(first, last, status, page_of(page)))
          in Failure(message) then bad_window(message)
        end
      end

      private

      def first_words(social_post)
        body = Blog::Helpers::Whitespace.squish(social_post.parts.first&.body)

        Blog::Helpers::Truncation.cut(body, keep: PREVIEW_LENGTH)
      end

      def listed(first, last, status, page)
        posts = post_queries.dated_between(from: first, to: last, page:, status:)
        social_posts = social_post_queries.unsent_page(page)

        {
          counts: post_queries.count_dated_between(from: first, to: last),
          posts: summaries(posts.rows),
          social_posts: social_posts.rows.map { preview(it) },
          **Blog::Helpers::Paging.fields(posts, social_posts),
        }
      end

      def preview(social_post) = { id: social_post.id, preview: first_words(social_post), status: social_post.status }

      def summaries(posts)
        figures = post_figure_queries.figures(posts)

        posts.map { serialized(Serializers::Post, it).merge(draft: it.status == DRAFT, **tally(it.id, figures)) }
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
