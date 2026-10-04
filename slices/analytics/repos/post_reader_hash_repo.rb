# frozen_string_literal: true

module Analytics
  module Repos
    class PostReaderHashRepo < Blog::DB::Repo
      def record(path:, reader_hash:, since: Readers.window_opened_at)
        post_reader_hashes.record(path:, reader_hash:, since:)
      end
    end
  end
end
