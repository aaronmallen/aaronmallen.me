# frozen_string_literal: true

RSpec.describe "Artifact tags moved into their join", type: :app do
  let(:gateway) { Hanami.app["db.rom"].gateways[:default] }
  let(:db) { gateway.connection }

  let(:migration) do
    ROM::SQL.with_gateway(gateway) { load "config/db/migrate/20261024040000_create_agent_tag_joins.rb" }
    Sequel::Migration.descendants.pop
  end

  def artifact(title, tags) = db[:artifacts].insert(title:, type: "plan", tags: Sequel.pg_array(tags, :text))

  def held(id)
    db[:artifact_tags].join(:tags, id: :tag_id).where(artifact_id: id).order(:name).select_map(%i[name scope])
  end

  before do
    db[:tags].insert(name: "perf", color: "mk-green", scope: "private")
    db[:tags].insert(name: "perf", color: "mk-blue", scope: "public")
    migration.apply(db, :down)
  end

  it "joins each artifact to the private tag of each name, making the ones missing", :aggregate_failures do
    plan = artifact("Plan", %w[site perf])
    bare = artifact("Bare", [])
    migration.apply(db, :up)

    expect(held(plan)).to eq([%w[perf private], %w[site private]])
    expect(held(bare)).to be_empty
  end

  it "keeps the tone of a private tag that already had the name" do
    artifact("Plan", %w[perf])
    migration.apply(db, :up)

    expect(db[:tags].where(name: "perf", scope: "private").select_map(:color)).to eq(["mk-green"])
  end

  it "puts the tags back in the column on the way down" do
    plan = artifact("Plan", %w[site perf])
    migration.apply(db, :up)
    migration.apply(db, :down)

    expect(db[:artifacts].where(id: plan).get(:tags)).to eq(%w[perf site])
  end
end
