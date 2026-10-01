# frozen_string_literal: true

RSpec.describe Record::Operations::StoreCommits do
  include Spec::DB::FactoryHelper.new(:record)

  let(:repo) { "aaronmallen/aaronmallen.me" }
  let(:store) { Record::Slice["operations.store_commits"] }

  def branch(name, *shas) = { name:, commits: shas.map { commit(it) } }

  def commit(sha)
    { sha:, message: "lib: a commit", additions: 1, deletions: 0, authored_at: Time.utc(2026, 8, 10, 14, 30) }
  end

  def lookups(statements) = statements.grep(/\ASELECT .*FROM "commits"/)

  def sha(char) = char * 40

  it "counts only the commits it had not stored before" do
    create(:commit, sha: sha("a"))

    expect(store.call(repo, [branch("main", sha("a"), sha("b"), sha("c"))])).to eq(2)
  end

  it "counts a commit found on two branches once" do
    expect(store.call(repo, [branch("main", sha("a")), branch("topic", sha("a"), sha("b"))])).to eq(2)
  end

  it "counts nothing for a page with no commits" do
    expect(store.call(repo, [branch("main")])).to eq(0)
  end

  it "looks up the commits it already holds in one query for the whole page" do
    branches = [branch("main", *%w[a b c].map { sha(it) }), branch("topic", *%w[d e].map { sha(it) })]

    expect(lookups(counting { store.call(repo, branches) }).size).to eq(1)
  end

  it "asks the database nothing for a page with no commits" do
    expect(counting { store.call(repo, [branch("main")]) }).to be_empty
  end
end
