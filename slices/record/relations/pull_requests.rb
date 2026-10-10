# frozen_string_literal: true

module Record
  module Relations
    class PullRequests < Blog::DB::Relation
      MOVED_AT = Sequel.function(:coalesce, :merged_at, :closed_at, :ready_at, :created_at)

      schema :pull_requests, infer: true

      def between(from, to)
        first, last = Blog::TimeZone.day_bounds(from, to)

        where(MOVED_AT => first...last)
      end

      def linkable = linkables(title: :title, day: self.class.site_day(MOVED_AT))

      def matching(text) = containing(text, :title, :body, :repo)

      def newest_first = order(Sequel.desc(MOVED_AT), self[:id].desc)
    end
  end
end
