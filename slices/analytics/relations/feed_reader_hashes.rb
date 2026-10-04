# frozen_string_literal: true

module Analytics
  module Relations
    class FeedReaderHashes < Blog::DB::Relation
      schema :feed_reader_hashes, infer: true

      def before(day) = where { self.day < day }
    end
  end
end
