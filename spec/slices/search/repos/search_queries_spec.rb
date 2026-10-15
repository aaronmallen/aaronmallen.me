# frozen_string_literal: true

RSpec.describe Search::Repos::SearchQueries do
  let(:db) { Search::Slice["db.rom"].gateways[:default].connection }
  let(:page) { Blog::Structs::Page.new(number: 1, size: 20) }

  describe "#search" do
    subject(:repo) { described_class.new }

    let(:task) do
      ["task", "Feed the sourdough sourdough starter sourdough", "Feed the sourdough sourdough starter sourdough\n"]
    end
    let(:message) { ["message", "Hello", "Re: Hello\nSourdough starter, sourdough loaf\nbaker@example.com"] }
    let(:journal) { ["journal", "Baked rye", "Baked rye\nThen a sourdough loaf"] }

    def hits(number: 1, size: 20)
      found = repo.search(text: "sourdough", page: Blog::Structs::Page.new(number:, size:))

      found.rows.map { [it.kind, it.title, it.match] }
    end

    before do
      thread = create(:message, subject: "Hello", body: "One sourdough loaf")
      create(
        :mail_message,
        mail_thread_id: thread.id, reply_to: "baker@example.com", subject: "Re: Hello",
        body: "Sourdough starter, sourdough loaf",
      )
      create(:task, title: "Feed the sourdough sourdough starter sourdough")
      create(:journal_entry, body: "Baked rye\nThen a sourdough loaf")
    end

    it "ranks each record once, headlined from its best match" do
      expect(hits).to eq([task, message, journal])
    end

    it "pages the ranked records" do
      expect(hits(number: 2, size: 2)).to eq([journal])
    end
  end

  describe "the query plan" do
    let(:tables) do
      %w[
        tasks posts social_post_parts journal_entries commits projects work_entries people mail_messages webmentions
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
