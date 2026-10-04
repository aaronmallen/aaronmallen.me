# frozen_string_literal: true

module Analytics
  module Relations
    class FeedReaders < Blog::DB::Relation
      ONE_MORE = { readers: Sequel[:feed_readers][:readers] + 1, updated_at: Sequel::CURRENT_TIMESTAMP }.freeze

      schema :feed_readers, infer: true

      def record(day:, path:, reader_hash:)
        hashes = dataset.db[:feed_reader_hashes].insert_conflict.returning(:day, :path)
        added = hashes.with_sql(:insert_sql, day:, path:, reader_hash:)

        counts = dataset.with(:added, added).insert_conflict(target: %i[day path], update: ONE_MORE)

        counts.insert(%i[day path readers], dataset.db[:added].select(:day, :path, 1))
      end
    end
  end
end
