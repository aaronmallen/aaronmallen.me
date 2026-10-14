# frozen_string_literal: true

RSpec.describe "Backfilling task projects and tags from rules", type: :app do
  let(:db) { Hanami.app["db.rom"].gateways[:default].connection }
  let(:path) { Hanami.app.root.join("config/db/migrate/20261015001000_backfill_task_projects_and_tags_from_rules.rb") }
  let(:queries) { Tasks::Slice["repos.task_queries"] }

  let(:blog) { create(:project) }
  let(:site) { create(:project, :archived) }

  before do
    create(:tag, :private, name: "ruby")
    rule("aaronmallen/aaronmallen.me", tags: "hanami")
    rule("aaronmallen/*", tags: "ruby, projects", projects: [blog.id])
    rule("acme/eng", tags: "linear", projects: [site.id], provider: "linear")
  end

  def backfill
    ROM::SQL.with_gateway(Hanami.app["db.rom"].gateways[:default]) { load path.to_s }
    Sequel::Migration.descendants.last.apply(db, :up)
  end

  def imported(url, provider: "github", **) = create(:task_source, provider:, url:, task: create(:task, :done, **)).task

  def project_id(task) = db[:tasks].where(id: task.id).get(:project_id)

  def rule(pattern, tags: "", projects: [], provider: "github")
    Tasks::Slice["operations.save_task_rule"].call({ pattern:, tags:, projects:, provider: }).value!
  end

  def tags(task) = queries.by_id(task.id).tags.map(&:name).sort

  it "gives a closed task the project and tags of every rule it matches" do
    task = imported("https://github.com/aaronmallen/aaronmallen.me/issues/7")

    backfill

    expect([project_id(task), tags(task)]).to eq([blog.id, %w[hanami projects ruby]])
  end

  it "gives a task the project that owns its repo over a rule's project" do
    owner = create(:project, repo: "aaronmallen/pod")
    task = imported("https://github.com/AaronMallen/Pod/issues/3")

    backfill

    expect([project_id(task), tags(task)]).to eq([owner.id, %w[projects ruby]])
  end

  it "matches a Linear task by workspace and team, archived projects included" do
    task = imported("https://linear.app/acme/issue/ENG-12/fix-it", provider: "linear")

    backfill

    expect([project_id(task), tags(task)]).to eq([site.id, %w[linear]])
  end

  it "keeps the project and tags a task already holds" do
    held = create(:project)
    task = imported("https://github.com/aaronmallen/aaronmallen.me/issues/8", project_id: held.id, tags: %w[mine])

    backfill

    expect([project_id(task), tags(task)]).to eq([held.id, %w[hanami mine projects ruby]])
  end

  it "leaves a task no rule or repo matches alone" do
    task = imported("https://github.com/someone/else/issues/1", tags: %w[mine])

    backfill

    expect([project_id(task), tags(task)]).to eq([nil, %w[mine]])
  end

  it "gives a task no rule from another provider" do
    task = imported("https://linear.app/aaronmallen/issue/ENG-1", provider: "linear")

    backfill

    expect([project_id(task), tags(task)]).to eq([nil, []])
  end
end
