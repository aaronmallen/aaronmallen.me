# frozen_string_literal: true

RSpec.describe "MCP tag tools", type: :request do
  let(:tag_repo) { Tags::Slice["repos.tag_repo"] }

  def access_token
    @access_token ||= mcp_connect(
      Spec::DB::Factories[:mcp].create(:oauth_client), verifier: MCP::OAuth::Secret.generate, scope: "read write",
    ).fetch("access_token")
  end

  def call_tool(name, **arguments) = rpc("tools/call", name:, arguments:)

  def content = JSON.parse(message)

  def error? = result.fetch("isError", false)

  def message = result.fetch("content").first.fetch("text")

  def result = JSON.parse(last_response.body).fetch("result")

  def rpc(method, **params)
    body = JSON.generate({ jsonrpc: "2.0", id: 1, method:, params: })

    post "/mcp", body, { "CONTENT_TYPE" => "application/json", "HTTP_AUTHORIZATION" => "Bearer #{access_token}" }
  end

  {
    "list_tags" => {},
    "save_tag" => { name: "ruby" },
    "remove_tag" => { id: 1 },
  }.each do |name, arguments|
    it "refuses #{name} without a scope, naming the field", :aggregate_failures do
      call_tool(name, **arguments)

      expect(error?).to be(true)
      expect(message).to include("scope")
    end
  end

  describe "list_tags" do
    before do
      create(:post, tags: %w[ruby])
      create(:project, tags: %w[ruby])
      create(:project, tags: %w[ruby cli])
      create(:tag, name: "unused")
      create(:task, tags: %w[chores ruby])
      call_tool("list_tags", scope: "public")
    end

    def named(name) = content.fetch("tags").find { it.fetch("name") == name }

    it "lists the public tags by name" do
      expect(content.fetch("tags").map { it.fetch("name") }).to eq(%w[cli ruby unused])
    end

    it "gives each tag its scope" do
      expect(content.fetch("tags").map { it.fetch("scope") }.uniq).to eq(%w[public])
    end

    it "counts the records that carry each tag, by kind" do
      expect(named("ruby")).to include("count" => 3, "by_kind" => { "posts" => 1, "projects" => 2 })
    end

    it "counts a tag nothing carries as zero" do
      expect(named("unused")).to include("count" => 0, "by_kind" => {})
    end

    describe "in the private scope" do
      before { call_tool("list_tags", scope: "private") }

      it "lists the private tags by name" do
        expect(content.fetch("tags").map { it.fetch("name") }).to eq(%w[chores ruby])
      end

      it "gives each tag its scope" do
        expect(content.fetch("tags").map { it.fetch("scope") }.uniq).to eq(%w[private])
      end

      it "counts a private tag by its private kinds" do
        expect(named("ruby")).to include("count" => 1, "by_kind" => { "tasks" => 1 })
      end
    end
  end

  describe "save_tag" do
    it "adds a public tag", :aggregate_failures do
      call_tool("save_tag", scope: "public", name: "Elixir", color: "mk-blue")

      expect(content).to include("name" => "elixir", "color" => "mk-blue")
      expect(tag_repo.all_in("public").map(&:name)).to eq(%w[elixir])
    end

    it "adds a private tag" do
      call_tool("save_tag", scope: "private", name: "chores")

      expect(tag_repo.all_in("private").map(&:name)).to eq(%w[chores])
    end

    it "takes a name the other scope holds" do
      create(:tag, name: "ruby")
      call_tool("save_tag", scope: "private", name: "ruby")

      expect(tag_repo.all_in("private").map(&:name)).to eq(%w[ruby])
    end

    it "recolours a tag and keeps its name" do
      tag = create(:tag, name: "ruby", color: "mk-pink")
      call_tool("save_tag", scope: "public", id: tag.id, color: "mk-green")

      expect(tag_repo.find_in("public", tag.id)).to have_attributes(name: "ruby", color: "mk-green")
    end

    it "renames a tag and keeps its colour" do
      tag = create(:tag, name: "ruby", color: "mk-pink")
      call_tool("save_tag", scope: "public", id: tag.id, name: "crystal")

      expect(tag_repo.find_in("public", tag.id)).to have_attributes(name: "crystal", color: "mk-pink")
    end

    it "recolours a private tag" do
      tag = create(:tag, :private, name: "chores", color: "mk-pink")
      call_tool("save_tag", scope: "private", id: tag.id, color: "mk-green")

      expect(tag_repo.find_in("private", tag.id)).to have_attributes(name: "chores", color: "mk-green")
    end

    it "loads only the tag it changes" do
      tag = create(:tag, name: "ruby")
      create(:tag, name: "elixir")
      reads = counting { call_tool("save_tag", scope: "public", id: tag.id, color: "mk-green") }.grep(/FROM "tags"/)

      expect(reads).to have_at_least(1).item.and all(include(%("tags"."id" = #{tag.id})))
    end

    it "refuses a tag from the other scope as not found", :aggregate_failures do
      tag = create(:tag, :private, name: "chores", color: "mk-pink")
      call_tool("save_tag", scope: "public", id: tag.id, name: "errands")

      expect(message).to eq("no tag has the ID #{tag.id}")
      expect(tag_repo.find_in("private", tag.id)).to have_attributes(name: "chores")
    end

    it "refuses a name another tag holds, with the reason the admin gives", :aggregate_failures do
      create(:tag, name: "ruby")
      call_tool("save_tag", scope: "public", name: "ruby")

      expect(error?).to be(true)
      expect(message).to eq("name: another tag already holds that name")
    end

    it "refuses a name that is not lowercase words joined by hyphens" do
      call_tool("save_tag", scope: "public", name: "two words")

      expect(message).to eq("name: a tag is lowercase words joined by hyphens")
    end

    it "names one rule as one" do
      Tasks::Slice["operations.save_task_tag_rule"].call({ pattern: "rails/*", tags: "ruby" })
      id = tag_repo.all_in("private").first.id
      call_tool("remove_tag", scope: "private", id:)

      expect(message).to eq("tag #{id} is the only tag on the task tag rule rails/*")
    end

    it "refuses an ID no tag has" do
      call_tool("save_tag", scope: "public", id: 999_999, name: "ghost")

      expect(message).to eq("no tag has the ID 999999")
    end

    it "refuses a scope that is neither public nor private" do
      call_tool("save_tag", scope: "secret", name: "ghost")

      expect(error?).to be(true)
    end
  end

  describe "remove_tag" do
    it "removes a tag nothing carries" do
      tag = create(:tag)
      call_tool("remove_tag", scope: "public", id: tag.id)

      expect(tag_repo.all_in("public")).to be_empty
    end

    it "removes a private tag nothing carries" do
      tag = create(:tag, :private)
      call_tool("remove_tag", scope: "private", id: tag.id)

      expect(tag_repo.all_in("private")).to be_empty
    end

    it "refuses a tag from the other scope as not found", :aggregate_failures do
      tag = create(:tag, :private)
      call_tool("remove_tag", scope: "public", id: tag.id)

      expect(message).to eq("no tag has the ID #{tag.id}")
      expect(tag_repo.find_in("private", tag.id)).not_to be_nil
    end

    it "removes a tag records carry" do
      create(:post, tags: %w[ruby rails])
      call_tool("remove_tag", scope: "public", id: tag_repo.all_in("public").find { it.name == "ruby" }.id)

      expect(tag_repo.all_in("public").map(&:name)).to eq(%w[rails])
    end

    it "takes the tag off every record that carried it", :aggregate_failures do
      post = create(:post, tags: %w[ruby rails])
      project = create(:project, tags: %w[ruby])
      call_tool("remove_tag", scope: "public", id: tag_repo.all_in("public").find { it.name == "ruby" }.id)

      expect(Posts::Slice["repos.post_repo"].by_id(post.id).tags.map(&:name)).to eq(%w[rails])
      expect(Projects::Slice["repos.project_repo"].by_id(project.id).tags).to be_empty
    end

    it "removes a private tag a task carries" do
      create(:task, tags: %w[chores])
      call_tool("remove_tag", scope: "private", id: tag_repo.all_in("private").first.id)

      expect(tag_repo.all_in("private")).to be_empty
    end

    it "refuses the only tag on a task tag rule, naming the rules", :aggregate_failures do
      %w[rails/* aaronmallen/*].each { Tasks::Slice["operations.save_task_tag_rule"].call({ pattern: it, tags: "ruby" }) }
      id = tag_repo.all_in("private").first.id
      call_tool("remove_tag", scope: "private", id:)

      expect(message).to eq("tag #{id} is the only tag on the task tag rules aaronmallen/*, rails/*")
      expect(tag_repo.find_in("private", id)).not_to be_nil
    end

    it "names one rule as one" do
      Tasks::Slice["operations.save_task_tag_rule"].call({ pattern: "rails/*", tags: "ruby" })
      id = tag_repo.all_in("private").first.id
      call_tool("remove_tag", scope: "private", id:)

      expect(message).to eq("tag #{id} is the only tag on the task tag rule rails/*")
    end

    it "refuses an ID no tag has" do
      call_tool("remove_tag", scope: "public", id: 999_999)

      expect(message).to eq("no tag has the ID 999999")
    end
  end
end
