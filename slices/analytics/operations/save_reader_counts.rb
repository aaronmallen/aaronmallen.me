# frozen_string_literal: true

module Analytics
  module Operations
    class SaveReaderCounts < Blog::Operation
      include Deps[reader_repo: "repos.post_reader_hash_repo"]

      def call = reader_repo.save_counts(since: Readers.window_opened_at)
    end
  end
end
