# frozen_string_literal: true

module Search
  module Repos
    class PublicSearchQueries < Blog::DB::Repo
      KINDS = Blog::Types::PublicSearchKind.values

      def counts(text:, kinds: KINDS)
        phrase = text.to_s.strip
        return Blog::Constants::EMPTY_HASH if phrase.empty?

        public_search_documents.kind_counts(phrase, kinds:).to_a.to_h { [it[:kind], it[:count]] }
      end

      def search(text:, page:, kinds: KINDS)
        phrase = text.to_s.strip
        return page.fill(Blog::Constants::EMPTY_ARRAY) if phrase.empty?

        page.fill(public_search_documents.hits(phrase, kinds:, page:).map { Structs::PublicHit.new(**it) })
      end
    end
  end
end
