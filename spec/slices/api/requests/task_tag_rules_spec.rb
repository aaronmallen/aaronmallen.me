# frozen_string_literal: true

RSpec.describe "API task tag rules", type: :request do
  def api_token = @api_token ||= API::Slice["operations.mint_token"].call(name: "Terminal").value!.fetch(:value)

  def call_api(verb, path, body = nil)
    headers = { "CONTENT_TYPE" => "application/json", "HTTP_ACCEPT" => "application/json" }
    headers["HTTP_AUTHORIZATION"] = "Bearer #{api_token}"
    public_send(verb, "/api/v1/task_tag_rules#{path}", body, headers)
    JSON.parse(last_response.body)
  end

  def create_rule(fields) = call_api(:post, "", JSON.generate(fields))

  def delete_rule(id) = call_api(:delete, "/#{id}")

  def linear(workspace, key)
    sourced("x", provider: "linear", url: "https://linear.app/#{workspace}/issue/#{key}/a-title")
  end

  def list = call_api(:get, "")

  def rule(pattern, tags, provider: nil)
    Tasks::Slice["operations.save_task_tag_rule"].call({ pattern:, provider:, tags: }).value!
  end

  def rules = Tasks::Slice["queries.task_tag_rules"].call

  def sourced(repo, provider: "github", url: "https://github.com/#{repo}/issues/1")
    create(:task, :external).tap { create(:task_source, task: it, provider:, url:) }
  end

  def status = last_response.status

  def tag_names(task) = Tasks::Slice["repos.task_repo"].by_id(task.id).tags.map(&:name)

  def update_rule(id, fields) = call_api(:patch, "/#{id}", JSON.generate(fields))

  describe "GET /api/v1/task_tag_rules" do
    it "lists each rule by pattern with its ID, pattern and tags" do
      later = rule("aaronmallen/aaronmallen.me", "ruby, hanami")
      first = rule("aaronmallen/*", "projects")

      expect(list.fetch("task_tag_rules").map { it.values_at("id", "pattern", "tags") })
        .to eq([[first.id, "aaronmallen/*", ["projects"]], [later.id, "aaronmallen/aaronmallen.me", %w[hanami ruby]]])
    end

    it "gives each rule's provider" do
      rule("acme/*", "work")
      rule("acme/ENG", "work", provider: "linear")

      expect(list.fetch("task_tag_rules").map { it.values_at("provider", "pattern") })
        .to eq([%w[github acme/*], %w[linear acme/eng]])
    end

    it "answers an empty list with 200" do
      expect([list, status]).to eq([{ "task_tag_rules" => [] }, 200])
    end
  end

  describe "POST /api/v1/task_tag_rules" do
    it "saves the rule and answers it with 201", :aggregate_failures do
      created = create_rule(pattern: "AaronMallen/*", tags: %w[projects ruby])

      expect(created.except("id"))
        .to eq("pattern" => "aaronmallen/*", "provider" => "github", "tags" => %w[projects ruby])
      expect(status).to eq(201)
    end

    it "saves a Linear rule and tags only the Linear tasks it matches", :aggregate_failures do
      eng = linear("acme", "ENG-12")
      github = sourced("acme/eng")
      created = create_rule(pattern: "acme/ENG", provider: "linear", tags: %w[work])

      expect(created.values_at("provider", "pattern")).to eq(%w[linear acme/eng])
      expect([tag_names(eng), tag_names(github)]).to eq([%w[work], []])
    end

    it "tags the Linear tasks from a team it matches in any case, and none from another workspace" do
      tasks = [linear("acme", "eng-12"), linear("Acme", "ENG-7"), linear("acme", "ops-3"), linear("octocat", "eng-1")]
      create_rule(pattern: "acme/ENG", provider: "linear", tags: %w[ruby])

      expect(tasks.map { tag_names(it) }).to eq([%w[ruby], %w[ruby], [], []])
    end

    it "tags every team in a workspace a Linear rule names with a star" do
      tasks = [linear("acme", "eng-12"), linear("acme", "ops-3"), linear("octocat", "eng-1")]
      create_rule(pattern: "acme/*", provider: "linear", tags: %w[ruby])

      expect(tasks.map { tag_names(it) }).to eq([%w[ruby], %w[ruby], []])
    end

    it "takes a GitHub rule and a Linear rule for the same pattern" do
      create_rule(pattern: "acme/*", provider: "github", tags: %w[work])
      create_rule(pattern: "acme/*", provider: "linear", tags: %w[work])

      expect(rules.map(&:provider)).to contain_exactly("github", "linear")
    end

    it "refuses a provider it does not know with a 422 and saves nothing", :aggregate_failures do
      expect([create_rule(pattern: "acme/*", provider: "jira", tags: %w[work]).fetch("errors").keys, status])
        .to eq([%w[provider], 422])
      expect(rules).to be_empty
    end

    it "tags every task already imported from a repo it matches" do
      task = sourced("aaronmallen/aaronmallen.me")
      create_rule(pattern: "aaronmallen/*", tags: %w[projects])

      expect(tag_names(task)).to eq(%w[projects])
    end

    it "creates each tag it names as a private tag" do
      create_rule(pattern: "aaronmallen/*", tags: %w[brand-new])

      expect(Tasks::Slice["relations.tags"].where(name: "brand-new").pluck(:scope)).to eq(%w[private])
    end

    it "tags only the repo a one repo pattern names, whatever its case" do
      tasks = [sourced("AaronMallen/AaronMallen.me"), sourced("aaronmallen/aaronmallen.me2")]
      create_rule(pattern: "aaronmallen/aaronmallen.me", tags: %w[ruby])

      expect(tasks.map { tag_names(it) }).to eq([%w[ruby], []])
    end

    it "tags no Linear task and no task without a source" do
      linear = sourced("aaronmallen/x", provider: "linear", url: "https://linear.app/aaronmallen/issue/ABC-1")
      plain = create(:task)
      create_rule(pattern: "aaronmallen/*", tags: %w[projects])

      expect([tag_names(linear), tag_names(plain)]).to eq([[], []])
    end

    it "keeps a tag a task already has once" do
      task = sourced("aaronmallen/aaronmallen.me")
      Tasks::Slice["repos.task_repo"].replace_tags(task.id, %w[ruby])
      create_rule(pattern: "aaronmallen/*", tags: %w[ruby projects])

      expect(tag_names(task)).to eq(%w[projects ruby])
    end

    it "records the tags on the task's timeline without marking it seen", :aggregate_failures do
      task = sourced("aaronmallen/aaronmallen.me")
      create_rule(pattern: "aaronmallen/*", tags: %w[projects])

      expect(Tasks::Slice["relations.task_events"].where(task_id: task.id).pluck(:kind)).to eq(%w[tagged])
      expect(Tasks::Slice["repos.task_repo"].by_id(task.id).source.seen_at).to be_nil
    end

    it "refuses a bad pattern with a 422 naming the field and saves nothing", :aggregate_failures do
      bad = "name one repo or team as owner/name, or all of an owner's as owner/*"

      expect([create_rule(pattern: "not a repo", tags: %w[ruby]), status])
        .to eq([{ "error" => "invalid", "message" => bad, "errors" => { "pattern" => [bad] } }, 422])
      expect(rules).to be_empty
    end

    it "refuses a pattern another rule holds" do
      rule("aaronmallen/*", "projects")

      expect(create_rule(pattern: "aaronmallen/*", tags: %w[ruby]).fetch("errors"))
        .to eq("pattern" => ["another rule already holds that pattern"])
    end

    it "refuses a pattern another Linear rule holds" do
      rule("acme/*", "ruby", provider: "linear")

      expect(create_rule(pattern: "acme/*", provider: "linear", tags: %w[go]).fetch("errors"))
        .to eq("pattern" => ["another rule already holds that pattern"])
    end

    it "refuses a rule with no tags" do
      expect(create_rule(pattern: "aaronmallen/*", tags: []).fetch("errors")).to eq("tags" => ["name a tag first"])
    end

    it "refuses a tag that is not lowercase words" do
      expect(create_rule(pattern: "aaronmallen/*", tags: ["ruby_rails"]).fetch("errors"))
        .to eq("tags" => ["a tag is lowercase words joined by hyphens"])
    end

    it "refuses a rule with no pattern" do
      expect(create_rule(tags: %w[ruby]).fetch("errors")).to eq("pattern" => ["pattern is missing"])
    end
  end

  describe "PATCH /api/v1/task_tag_rules/:id" do
    let(:saved) { rule("aaronmallen/*", "projects") }

    it "replaces the tags and keeps the pattern" do
      expect(update_rule(saved.id, tags: %w[ruby hanami]))
        .to eq("id" => saved.id, "pattern" => "aaronmallen/*", "provider" => "github", "tags" => %w[hanami ruby])
    end

    it "changes the provider" do
      expect(update_rule(saved.id, provider: "linear")).to include("provider" => "linear", "pattern" => "aaronmallen/*")
    end

    it "keeps the provider when it is left out" do
      linear = rule("acme/*", "work", provider: "linear")

      expect(update_rule(linear.id, tags: %w[ruby])).to include("provider" => "linear")
    end

    it "changes the pattern and keeps the tags" do
      expect(update_rule(saved.id, pattern: "aaronmallen/blog"))
        .to include("pattern" => "aaronmallen/blog", "tags" => ["projects"])
    end

    it "tags no task already imported" do
      task = sourced("octocat/hello-world")
      update_rule(saved.id, pattern: "octocat/*", tags: %w[ruby])

      expect(tag_names(task)).to be_empty
    end

    it "tags no Linear task already imported when a Linear rule is edited to match it" do
      task = linear("acme", "eng-12")
      update_rule(rule("octocat/*", "ruby", provider: "linear").id, pattern: "acme/*", tags: %w[go])

      expect(tag_names(task)).to be_empty
    end

    it "refuses a bad pattern with a 422 and keeps the old one" do
      update_rule(saved.id, pattern: "nope")

      expect([status, rules.map(&:pattern)]).to eq([422, ["aaronmallen/*"]])
    end

    it "answers an unknown ID with a 404" do
      expect([update_rule(999_999, tags: %w[ruby]), status])
        .to eq([{ "error" => "not_found", "message" => "no task tag rule has the ID 999999" }, 404])
    end
  end

  describe "DELETE /api/v1/task_tag_rules/:id" do
    it "removes the rule and leaves task tags as they were", :aggregate_failures do
      task = sourced("aaronmallen/aaronmallen.me")
      saved = rule("aaronmallen/*", "projects")

      expect(delete_rule(saved.id)).to eq("id" => saved.id, "deleted" => true)
      expect([rules, tag_names(task)]).to eq([[], %w[projects]])
    end

    it "answers an unknown ID with a 404" do
      expect([delete_rule(999_999), status])
        .to eq([{ "error" => "not_found", "message" => "no task tag rule has the ID 999999" }, 404])
    end
  end

  describe "the MCP tools" do
    it "list as list_task_tag_rules does" do
      rule("aaronmallen/*", "projects")

      expect(mcp_answer("list_task_tag_rules")).to eq(list)
    end

    it "add as save_task_tag_rule does with no id" do
      created = create_rule(pattern: "aaronmallen/*", tags: %w[projects])
      delete_rule(created.fetch("id"))

      expect(mcp_answer("save_task_tag_rule", pattern: "aaronmallen/*", tags: %w[projects]).except("id"))
        .to eq(created.except("id"))
    end

    it "edit as save_task_tag_rule does with an id" do
      saved = rule("aaronmallen/*", "projects")
      updated = update_rule(saved.id, tags: %w[ruby])

      expect(mcp_answer("save_task_tag_rule", id: saved.id, tags: %w[ruby])).to eq(updated)
    end

    it "delete as delete_task_tag_rule does" do
      saved = rule("aaronmallen/*", "projects")

      expect(mcp_answer("delete_task_tag_rule", id: saved.id)).to eq("id" => saved.id, "deleted" => true)
    end

    it "refuse with the message the endpoint gives", :aggregate_failures do
      refused = create_rule(pattern: "not a repo", tags: %w[ruby])
      answer = mcp_call("save_task_tag_rule", pattern: "not a repo", tags: %w[ruby])

      expect(answer["isError"]).to be(true)
      expect(answer.fetch("content").first.fetch("text")).to eq(refused.fetch("message"))
    end
  end
end
