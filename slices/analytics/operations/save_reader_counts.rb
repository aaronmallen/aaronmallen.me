# frozen_string_literal: true

module Analytics
  module Operations
    class SaveReaderCounts
      include Deps[
        reader_mutations: "repos.post_reader_mutations",
        reader_window_start: "operations.find_reader_window_start",
      ]

      def call = reader_mutations.save_counts(since: reader_window_start.call)
    end
  end
end
