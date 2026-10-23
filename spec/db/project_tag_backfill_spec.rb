# frozen_string_literal: true

RSpec.describe "Private tags moved into their projects", type: :app do
  let(:gateway) { Hanami.app["db.rom"].gateways[:default] }
  let(:db) { gateway.connection }
  let(:ids) do
    site = create(:project).id
    {
      site:, cli: create(:project).id, task: create(:task, project_id: site).id, decision: create(:decision).id,
      entry: create(:journal_entry).id, note: create(:note).id, filed: rule("aaronmallen/site", site),
      loose: rule("aaronmallen/*"),
    }
  end

  let(:migration) do
    ROM::SQL.with_gateway(gateway) { load "config/db/migrate/20261024050000_move_private_tags_into_projects.rb" }
    Sequel::Migration.descendants.pop
  end

  def held(table, owner_key, id)
    tags = db[table].join(:tags, id: :tag_id).where(owner_key => id)
    tags.order(:project_id, :name).select_map([:name, :scope, Sequel[:tags][:project_id]])
  end

  def link(left_kind, left_id, right_kind, right_id)
    db[:record_links].insert(left_kind:, left_id:, right_kind:, right_id:)
  end

  def project_tags(project, *names) = names.map { [it, "project", ids.fetch(project)] }

  def rule(pattern, project = nil)
    db[:task_rules].insert(pattern:, provider: "github").tap do |id|
      db[:task_rule_projects].insert(task_rule_id: id, project_id: project) if project
    end
  end

  def tag(name, **) = db[:tags].insert(name:, color: "mk-violet", scope: "private", **)

  def tagged(table, owner_key, id, tag_id) = db[table].insert(owner_key => id, tag_id:)

  before do
    bug = tag("bug", description: "broken")
    triage = tag("triage")
    infra = tag("infra")
    tag("unused")
    db[:tags].insert(name: "triage", color: "mk-blue", scope: "project", project_id: ids[:site])
    link("project", ids[:site], "decision", ids[:decision])
    link("project", ids[:cli], "decision", ids[:decision])
    link("journal_entry", ids[:entry], "project", ids[:cli])
    tagged(:task_tags, :task_id, ids[:task], bug)
    tagged(:task_tags, :task_id, ids[:task], tag("perf"))
    tagged(:decision_tags, :decision_id, ids[:decision], bug)
    tagged(:journal_entry_tags, :journal_entry_id, ids[:entry], bug)
    tagged(:note_tags, :note_id, ids[:note], bug)
    tagged(:task_rule_tags, :task_rule_id, ids[:filed], triage)
    tagged(:task_rule_tags, :task_rule_id, ids[:loose], infra)
    migration.apply(db, :up)
  end

  it "moves the private tags on each project record into its project", :aggregate_failures do
    expect(held(:task_tags, :task_id, ids[:task])).to eq(project_tags(:site, "bug", "perf"))
    expect(held(:journal_entry_tags, :journal_entry_id, ids[:entry])).to eq(project_tags(:cli, "bug"))
  end

  it "gives a record linked to two projects the tag in both" do
    both = project_tags(:site, "bug") + project_tags(:cli, "bug")

    expect(held(:decision_tags, :decision_id, ids[:decision])).to eq(both)
  end

  it "copies the tone and description into each project" do
    expect(db[:tags].where(name: "bug", scope: "project").select_map(%i[color description]).uniq)
      .to eq([%w[mk-violet broken]])
  end

  it "files a rule's tags under the project it files into, keeping that project's tone", :aggregate_failures do
    expect(held(:task_rule_tags, :task_rule_id, ids[:filed])).to eq(project_tags(:site, "triage"))
    expect(db[:tags].where(name: "triage", project_id: ids[:site]).get(:color)).to eq("mk-blue")
  end

  it "leaves the private tags on records with no project", :aggregate_failures do
    expect(held(:task_rule_tags, :task_rule_id, ids[:loose])).to eq([["infra", "private", nil]])
    expect(held(:note_tags, :note_id, ids[:note])).to eq([["bug", "private", nil]])
  end

  it "deletes each private tag left holding nothing and keeps the rest" do
    expect(db[:tags].where(scope: "private").order(:name).select_map(:name)).to eq(%w[bug infra unused])
  end
end
