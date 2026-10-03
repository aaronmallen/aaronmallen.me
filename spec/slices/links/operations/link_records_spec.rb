# frozen_string_literal: true

RSpec.describe Links::Operations::LinkRecords do
  include Dry::Monads[:result]

  let(:kinds) { Blog::Types::RecordKind.values }

  def link(kind, id, other_kind, other_id)
    Links::Slice["operations.link_records"].call(kind, id, { other_kind:, other_id: })
  end

  def linked(kind, id) = Links::Slice["queries.record_links"].call(kind, id)

  def stored = Links::Slice["relations.record_links"].to_a

  describe "any two kinds" do
    let(:records) { kinds.to_h { [it, linkable_record(it)] } }
    let(:pairs) { kinds.combination(2).to_a }

    before { pairs.each { |one, two| link(one, records[one].id, two, records[two].id).value! } }

    it "links every pair of kinds" do
      expect(stored.length).to eq(pairs.length)
    end

    it "reads each link from both sides", :aggregate_failures do
      pairs.each do |one, two|
        expect(linked(one, records[one].id)[two].map(&:id)).to eq([records[two].id])
        expect(linked(two, records[two].id)[one].map(&:id)).to eq([records[one].id])
      end
    end
  end

  describe "one link" do
    let(:post) { linkable_record("post") }
    let(:commit) { linkable_record("commit") }

    before { link("commit", commit.id, "post", post.id).value! }

    it "keeps one row, sorted by kind" do
      expect(stored.map { it.values_at(:left_kind, :left_id, :right_kind, :right_id) })
        .to eq([["post", post.id, "commit", commit.id]])
    end

    it "refuses the same pair again" do
      expect(link("commit", commit.id, "post", post.id)).to eq(Failure([:invalid, { other_id: ["taken"] }]))
    end

    it "refuses the pair in the other order" do
      expect(link("post", post.id, "commit", commit.id)).to eq(Failure([:invalid, { other_id: ["taken"] }]))
    end
  end

  it "sorts two records of one kind by id" do
    first, second = Array.new(2) { linkable_record("project") }
    link("project", second.id, "project", first.id).value!

    expect(stored.map { it.values_at(:left_id, :right_id) }).to eq([[first.id, second.id]])
  end

  it "refuses a record linked to itself" do
    entry = linkable_record("journal_entry")

    expect(link("journal_entry", entry.id, "journal_entry", entry.id))
      .to eq(Failure([:invalid, { other_id: ["self"] }]))
  end

  it "refuses a task linked to itself as a self link" do
    task = linkable_record("task")

    expect(link("task", task.id, "task", task.id)).to eq(Failure([:invalid, { other_id: ["self"] }]))
  end

  it "refuses two tasks, which task links hold" do
    one, two = Array.new(2) { linkable_record("task") }

    expect(link("task", one.id, "task", two.id)).to eq(Failure([:invalid, { other_id: ["task_pair"] }]))
  end

  it "refuses a record that does not exist" do
    post = linkable_record("post")

    expect(link("post", post.id, "decision", 999_999)).to eq(Failure([:invalid, { other_id: ["missing"] }]))
  end

  it "refuses a kind it does not know" do
    post = linkable_record("post")

    expect(link("post", post.id, "person", 1)).to eq(Failure([:invalid, { other_kind: ["format"] }]))
  end

  it "refuses a missing id" do
    post = linkable_record("post")

    expect(link("post", post.id, "decision", nil)).to eq(Failure([:invalid, { other_id: ["format"] }]))
  end

  describe "a record to link from that is not there" do
    let(:decision) { linkable_record("decision") }

    it "answers not found for a missing id" do
      expect(link("post", 999_999, "decision", decision.id)).to eq(Failure(:not_found))
    end

    it "answers not found for an unknown kind" do
      expect(link("person", 1, "decision", decision.id)).to eq(Failure(:not_found))
    end

    it "answers not found for an id that is not a number" do
      expect(link("post", "abc", "decision", decision.id)).to eq(Failure(:not_found))
    end
  end
end
