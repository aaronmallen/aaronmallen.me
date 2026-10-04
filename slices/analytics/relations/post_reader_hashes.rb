# frozen_string_literal: true

module Analytics
  module Relations
    class PostReaderHashes < Blog::DB::Relation
      POST_PATH = Sequel.join(["#{Blog::Site::WRITING}/", Sequel[:posts][:slug]])
      PUBLISHED = Blog::Types::PostStatus["published"]

      schema :post_reader_hashes, infer: true

      def closed(since) = where(path: dataset.db[:posts].where { published_at <= since }.select(POST_PATH))

      def counts_by_path = unordered.select(:path) { integer.count(:reader_hash).as(:readers) }.group(:path)

      def for_paths(paths) = where(path: paths)

      def orphaned = exclude(path: dataset.db[:posts].select(POST_PATH))

      def record(path:, reader_hash:, since:)
        post = dataset.db[:posts].where(status: PUBLISHED, POST_PATH => path).where { published_at > since }

        dataset.insert_conflict.insert(%i[path reader_hash], post.select(path, reader_hash))
      end
    end
  end
end
