# frozen_string_literal: true

RSpec.describe Search::Repos::SearchQueries do
  let(:db) { Search::Slice["db.rom"].gateways[:default].connection }
  let(:page) { Blog::Structs::Page.new(number: 1, size: 20) }

  describe "the query plan" do
    let(:tables) do
      %w[
        tasks posts social_post_parts journal_entries commits projects work_entries people messages webmentions
        decisions pull_requests
      ]
    end
    let(:indexes) { tables.map { "#{it}_search_vector_index" } }

    def plan
      db.transaction do
        db.run("ANALYZE #{tables.join(', ')}")
        db.run("SET LOCAL enable_seqscan = off")
        db.run("SET LOCAL enable_indexscan = off")
        db["EXPLAIN #{sql}"].map(:"QUERY PLAN").join("\n")
      end
    end

    def sql
      relation = Search::Slice["relations.search_documents"]

      relation.hits("x", kinds: Blog::Types::SearchKind.values, page:).sql
    end

    it "reads each table's index" do
      expect(plan).to include(*indexes)
    end
  end
end
