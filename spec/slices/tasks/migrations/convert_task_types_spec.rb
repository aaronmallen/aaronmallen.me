# frozen_string_literal: true

RSpec.describe "Converting task types to tags", type: :migration do
  let(:gateway) { Tasks::Slice["db.rom"].gateways[:default] }
  let(:db) { gateway.connection }
  let(:task) { create(:task) }

  def migrate(target = nil)
    path = Hanami.app.root.join("config/db/migrate").to_s

    ROM::SQL.with_gateway(gateway) { Sequel::Migrator.run(db, path, **{ target: }.compact) }
  end

  def tag_names = db[:task_tags].join(:tags, id: :tag_id).where(task_id: task.id).order(:name).select_map(:name)

  def type(name) = db[:task_types].insert(name:, color: "mk-blue", position: 1)

  def type_task(name) = db[:tasks].where(id: task.id).update(task_type_id: type(name))

  before do
    task
    migrate(20_260_928_000_037)
  end

  it "tags each task that held a type with the type's name as a slug" do
    type_task("Bug Fix")
    migrate

    expect(tag_names).to eq(["bug-fix"])
  end

  describe "a type whose name a tag holds" do
    let!(:tag) { create(:tag, name: "chore", color: "mk-sand") }

    before do
      type_task("Chore")
      migrate
    end

    it "tags the task with that tag" do
      expect(tag_names).to eq(["chore"])
    end

    it "keeps the tag as it was" do
      expect(db[:tags].where(name: "chore").select_map(%i[id color])).to eq([[tag.id, "mk-sand"]])
    end
  end

  describe "a task that already carried the matching tag" do
    let(:task) { create(:task, tags: %w[spike ruby]) }

    it "keeps its tags as they were" do
      type_task("Spike")
      migrate

      expect(tag_names).to eq(%w[ruby spike])
    end
  end

  it "leaves a task that held no type untagged" do
    type("Writing")
    migrate

    expect(tag_names).to be_empty
  end

  it "turns a type nobody used into a tag all the same" do
    type("Writing")
    migrate

    expect(db[:tags].where(name: "writing").count).to eq(1)
  end

  it "drops the type table and the task's type column", :aggregate_failures do
    migrate

    expect(db.table_exists?(:task_types)).to be(false)
    expect(db[:tasks].columns).not_to include(:task_type_id)
  end
end
