# frozen_string_literal: true

module Analytics
  module Relations
    class PostReaderHashes < Blog::DB::Relation
      POST_PATH = Sequel.join(["#{Blog::Site::WRITING}/", Sequel[:posts][:slug]])
      PUBLISHED = Blog::Types::PostStatus["published"]

      schema :post_reader_hashes, infer: true

      def record(path:, reader_hash:, since:)
        post = dataset.db[:posts].where(status: PUBLISHED, POST_PATH => path).where { published_at > since }

        dataset.insert_conflict.insert(%i[path reader_hash], post.select(path, reader_hash))
      end
    end
  end
end
