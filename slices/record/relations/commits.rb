# frozen_string_literal: true

module Record
  module Relations
    class Commits < Blog::DB::Relation
      LINE_TOTALS = proc do
        [
          integer.coalesce(integer.sum(additions), 0).as(:additions),
          integer.coalesce(integer.sum(deletions), 0).as(:deletions),
        ]
      end
      OWNER_SEPARATOR = "/"

      schema :commits, infer: true

      def between(from, to) = where(commit_date: from..to)

      def in_repos(names) = where(Sequel.|(*names.map { named_repo(it) }))

      def line_totals = unordered.select(&LINE_TOTALS)

      def newest_first = order(self[:commit_date].desc, self[:commit_time].desc, self[:id].desc)

      def on(date) = where(commit_date: date)

      def repo_names = unordered.distinct.order(:repo).pluck(:repo)

      def with_sha(sha) = where(sha:)

      private

      def named_repo(name)
        folded = name.to_s.downcase
        column = folded.include?(OWNER_SEPARATOR) ? :repo : Sequel.function(:split_part, :repo, OWNER_SEPARATOR, 2)

        Sequel[Sequel.function(:lower, column) => folded]
      end
    end
  end
end
