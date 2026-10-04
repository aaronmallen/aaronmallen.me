# frozen_string_literal: true

module Analytics
  module Relations
    class PostReaderCounts < Blog::DB::Relation
      ADDED = { readers: Sequel[:post_reader_counts][:readers] + Sequel[:excluded][:readers] }.freeze

      schema :post_reader_counts, infer: true

      def for_paths(paths) = where(path: paths)

      def save(counts)
        update = { **ADDED, updated_at: Sequel::CURRENT_TIMESTAMP }

        dataset.insert_conflict(target: :path, update:).insert(%i[path readers], counts.dataset)
      end
    end
  end
end
