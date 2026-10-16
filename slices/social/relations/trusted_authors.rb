# frozen_string_literal: true

module Social
  module Relations
    class TrustedAuthors < Blog::DB::Relation
      schema :trusted_authors, infer: true

      def newest_first = order(self[:created_at].desc, self[:author_url].asc)

      def trust(author_url) = dataset.insert_conflict.returning(:author_url).insert(author_url:)
    end
  end
end
