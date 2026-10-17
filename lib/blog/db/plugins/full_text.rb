# frozen_string_literal: true

module Blog
  module DB
    module Plugins
      module FullText
        CONFIG = "english"
        HEADLINE = 'MaxWords=24, MinWords=12, StartSel="", StopSel=""'
        RANKED = [
          Sequel.desc(:labelled), Sequel.desc(:rank), Sequel.desc(:day), Sequel.desc(:source_id), Sequel.asc(:kind),
        ].freeze
        TASK = "task"

        def hits(phrase, kinds:, page:, labelled: Blog::Constants::EMPTY_ARRAY)
          return none if unmatchable?(phrase)

          query = tsquery(phrase)
          found = best(query, kinds, labelled).order(*RANKED).limit(page.limit).offset(page.offset)

          with_body(found, query, labelled).select(*self.class::LINKED, headline(query)).order(*RANKED)
        end

        def kind_counts(phrase, kinds:, labelled: Blog::Constants::EMPTY_ARRAY)
          return none if unmatchable?(phrase)

          best(tsquery(phrase), kinds, labelled).group_and_count(:kind)
        end

        private

        def best(query, kinds, labelled)
          linked = [*self.class::LINKED, rank(query).as(:rank), labelled_task(labelled).as(:labelled)]
          ranked = matching(query, labelled).where(kind: kinds).select(*linked)

          ranked.distinct(:kind, :source_id).order(:kind, :source_id, Sequel.desc(:rank)).from_self(alias: :best)
        end

        def headline(query)
          Sequel.function(:ts_headline, CONFIG, Sequel[:top][:body], query, self.class::HEADLINE).as(:match)
        end

        def labelled_task(ids) = Sequel.&({ kind: TASK }, { source_id: ids })

        def matching(query, labelled)
          found = dataset.unordered.full_text_search(:search_vector, query, tsvector: true, tsquery: true)

          labelled.empty? ? found : found.or(labelled_task(labelled))
        end

        def rank(query) = Sequel.function(:ts_rank, :search_vector, query)

        def tsquery(phrase) = Sequel.function(:websearch_to_tsquery, CONFIG, phrase)

        def with_body(found, query, labelled)
          same = { kind: Sequel[:found][:kind], source_id: Sequel[:found][:source_id] }
          top = matching(query, labelled).where(same).select(:body).order(Sequel.desc(rank(query))).limit(1)

          found.from_self(alias: :found).cross_join(top.lateral.as(:top))
        end
      end
    end
  end
end
