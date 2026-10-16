# frozen_string_literal: true

RSpec.describe "Adding task rules for project repos", type: :app do
  let(:db) { Hanami.app["db.rom"].gateways[:default].connection }
  let(:path) { Hanami.app.root.join("config/db/migrate/20261016002092_add_task_rules_for_project_repos.rb") }

  def migrate
    ROM::SQL.with_gateway(Hanami.app["db.rom"].gateways[:default]) { load path.to_s }
    Sequel::Migration.descendants.last.apply(db, :up)
  end

  def rule(pattern, projects: [], provider: "github")
    Tasks::Slice["operations.save_task_rule"].call({ pattern:, tags: "ruby", projects:, provider: }).value!
  end

  def rules = Tasks::Slice["repos.task_rule_queries"].all.map { [it.provider, it.pattern, it.projects.map(&:id)] }

  it "adds a GitHub rule for each project whose repo no rule names" do
    blog = create(:project, :archived, repo: "aaronmallen/blog")
    create(:project, repo: nil)

    migrate

    expect(rules).to eq([["github", "aaronmallen/blog", [blog.id]]])
  end

  it "gives a rule for the repo that holds no project the project" do
    blog = create(:project, repo: "aaronmallen/blog")
    rule("aaronmallen/blog")

    migrate

    expect(rules).to eq([["github", "aaronmallen/blog", [blog.id]]])
  end

  it "leaves a rule for the repo that names another project alone" do
    other = create(:project, repo: nil)
    create(:project, repo: "aaronmallen/blog")
    rule("aaronmallen/blog", projects: [other.id])

    migrate

    expect(rules).to eq([["github", "aaronmallen/blog", [other.id]]])
  end

  it "adds an exact rule beside an owner rule" do
    blog = create(:project, repo: "aaronmallen/blog")
    rule("aaronmallen/*")

    migrate

    expect(rules).to eq([["github", "aaronmallen/*", []], ["github", "aaronmallen/blog", [blog.id]]])
  end

  it "adds a GitHub rule beside a Linear rule of the same name" do
    blog = create(:project, repo: "aaronmallen/blog")
    rule("aaronmallen/blog", provider: "linear")

    migrate

    expect(rules).to eq([["github", "aaronmallen/blog", [blog.id]], ["linear", "aaronmallen/blog", []]])
  end
end
