# frozen_string_literal: true

module Search
  module Relations
    class SearchDocuments < Blog::DB::Relation
      CONFIG = "english"
      HEADLINE = 'MaxWords=24, MinWords=12, StartSel="", StopSel=""'
      LINKED = %i[kind source_id title day status].freeze
      RANKED = [Sequel.desc(:rank), Sequel.desc(:day), Sequel.desc(:source_id), Sequel.asc(:kind)].freeze

      schema :search_documents, infer: true

      def hits(phrase, kinds:, page:)
        return none if unmatchable?(phrase)

        query = tsquery(phrase)
        found = best(query, kinds).order(*RANKED).limit(page.limit).offset(page.offset)

        with_body(found, query).select(*LINKED, headline(query)).order(*RANKED)
      end

      def kind_counts(phrase, kinds:)
        return none if unmatchable?(phrase)

        best(tsquery(phrase), kinds).group_and_count(:kind)
      end

      private

      def best(query, kinds)
        ranked = matching(query).where(kind: kinds).select(*LINKED, rank(query).as(:rank))

        ranked.distinct(:kind, :source_id).order(:kind, :source_id, Sequel.desc(:rank)).from_self(alias: :best)
      end

      def headline(query) = Sequel.function(:ts_headline, CONFIG, Sequel[:top][:body], query, HEADLINE).as(:match)

      def matching(query) = dataset.unordered.where(Sequel.lit("search_vector @@ ?", query))

      def rank(query) = Sequel.function(:ts_rank, :search_vector, query)

      def tsquery(phrase) = Sequel.function(:websearch_to_tsquery, CONFIG, phrase)

      def with_body(found, query)
        same = { kind: Sequel[:found][:kind], source_id: Sequel[:found][:source_id] }
        top = matching(query).where(same).select(:body).order(Sequel.desc(rank(query))).limit(1)

        found.from_self(alias: :found).cross_join(top.lateral.as(:top))
      end
    end
  end
end
