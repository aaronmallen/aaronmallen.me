# frozen_string_literal: true

module Search
  module Repos
    class SearchQueries < Blog::DB::Repo
      NONE = Blog::Constants::EMPTY_ARRAY
      TASK = Blog::Types::SearchKind["task"]

      include Deps["tasks.repos.task_label_queries"]

      def counts(text:, kinds: Blog::Types::SearchKind.values)
        phrase = text.to_s.strip
        return Blog::Constants::EMPTY_HASH if phrase.empty?

        labelled = task_label_queries.ids_labelled(phrase)
        search_documents.kind_counts(phrase, kinds:, labelled:).to_a.to_h { [it[:kind], it[:count]] }
      end

      def search(text:, page:, kinds: Blog::Types::SearchKind.values, open_people: false)
        phrase = text.to_s.strip
        return page.fill(NONE) if phrase.empty?

        documents = open_people ? search_documents.open_people : search_documents
        rows = documents.hits(phrase, kinds:, page:, labelled: task_label_queries.ids_labelled(phrase)).to_a
        page.fill(labelled(rows))
      end

      private

      def labelled(rows)
        labels = task_label_queries.labels(rows.filter_map { it[:source_id] if it[:kind] == TASK })

        rows.map { Structs::Hit.new(**it, label: (labels[it[:source_id]] if it[:kind] == TASK)) }
      end
    end
  end
end
