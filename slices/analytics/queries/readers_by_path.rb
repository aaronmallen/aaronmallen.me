# frozen_string_literal: true

module Analytics
  module Queries
    class ReadersByPath
      include Deps[reader_repo: "repos.post_reader_hash_repo"]

      def call(paths)
        live = reader_repo.live_counts(paths)
        saved = reader_repo.saved_counts(paths)

        (saved.keys | live.keys).to_h do |path|
          [path, { readers: saved.fetch(path, 0) + live.fetch(path, 0), final: !live.key?(path) }]
        end
      end
    end
  end
end
