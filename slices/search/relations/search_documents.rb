# frozen_string_literal: true

module Search
  module Relations
    class SearchDocuments < Blog::DB::Relation
      CONFIG = "english"
      HEADLINE = 'MaxWords=24, MinWords=12, StartSel="", StopSel=""'
      LINKED = %i[kind source_id title day status slug repo sha url].freeze
      RANKED = [Sequel.desc(:rank), Sequel.desc(:day), Sequel.desc(:source_id), Sequel.asc(:kind)].freeze

      schema :search_documents, infer: true

      def hits(phrase, kinds:, per_kind:, page:)
        return none if unmatchable?(phrase)

        query = Sequel.function(:websearch_to_tsquery, CONFIG, phrase)
        found = capped(best(query, kinds), per_kind).order(*RANKED).limit(page.limit).offset(page.offset)

        found.from_self(alias: :found).select(*LINKED, headline(query)).order(*RANKED)
      end

      private

      def best(query, kinds)
        matched = dataset.unordered.where(kind: kinds).where(Sequel.lit("search_vector @@ ?", query))

        ranked = matched.select(*LINKED, :body, Sequel.function(:ts_rank, :search_vector, query).as(:rank))

        ranked.distinct(:kind, :source_id).order(:kind, :source_id, Sequel.desc(:rank)).from_self(alias: :best)
      end

      def capped(found, per_kind)
        return found unless per_kind

        placed = found.select_append(Sequel.function(:row_number).over(partition: :kind, order: RANKED).as(:place))

        placed.from_self(alias: :placed).where(Sequel[:place] <= per_kind)
      end

      def headline(query) = Sequel.function(:ts_headline, CONFIG, :body, query, HEADLINE).as(:match)
    end
  end
end
