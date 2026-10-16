# frozen_string_literal: true

module Posts
  module Repos
    class PostFigureQueries < Blog::DB::Repo
      include Deps[
        post_reader_queries: "analytics.repos.post_reader_queries",
        rollup_queries: "analytics.repos.analytics_rollup_queries",
        webmention_queries: "social.repos.webmention_queries",
      ]

      UNSEEN = { read_throughs: 0, views: 0, visitors: 0 }.freeze

      def figures(posts)
        ids = posts.map(&:id)
        seen = rollup_queries.views_by_post(ids)
        readers = post_reader_queries.unique_readers(posts)
        mentions = webmention_queries.count_by_post(ids)

        ids.to_h { [it, { **seen.fetch(it, UNSEEN), readers: readers.fetch(it), mentions: mentions.fetch(it, 0) }] }
      end
    end
  end
end
