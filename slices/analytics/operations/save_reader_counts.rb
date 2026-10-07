# frozen_string_literal: true

module Analytics
  module Operations
    class SaveReaderCounts < Operation
      include Deps[reader_mutations: "repos.post_reader_mutations"]

      def call = reader_mutations.save_counts(since: Readers.window_opened_at)
    end
  end
end
