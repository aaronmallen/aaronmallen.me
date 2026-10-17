# frozen_string_literal: true

module Analytics
  module Relations
    class PostReaderHashes < Blog::DB::Relation
      PUBLISHED = Blog::Types::PostStatus["published"]

      schema :post_reader_hashes, infer: true

      def closed(since) = where(path: dataset.db[:posts].where { published_at <= since }.select(post_path))

      def counts_by_path = unordered.select(:path) { integer.count(:reader_hash).as(:readers) }.group(:path)

      def for_paths(paths) = where(path: paths)

      def orphaned = exclude(path: dataset.db[:posts].select(post_path))

      def record(path:, reader_hash:, since:)
        post = dataset.db[:posts].where(status: PUBLISHED, post_path => path).where { published_at > since }

        dataset.insert_conflict.insert(%i[path reader_hash], post.select(path, reader_hash))
      end

      private

      def post_path = AnalyticsRollupPaths::POST_PATH
    end
  end
end
