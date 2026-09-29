# frozen_string_literal: true

RSpec.describe "MCP tag tools", type: :request do
  let(:tag_repo) { Tags::Slice["repos.tag_repo"] }

  def access_token
    @access_token ||= mcp_connect(
      Spec::DB::Factories[:mcp].create(:oauth_client), verifier: MCP::OAuth::Secret.generate, scope: "read write",
    ).fetch("access_token")
  end

  def call_tool(name, **arguments)
    body = JSON.generate({ jsonrpc: "2.0", id: 1, method: "tools/call", params: { name:, arguments: } })

    post "/mcp", body, { "CONTENT_TYPE" => "application/json", "HTTP_AUTHORIZATION" => "Bearer #{access_token}" }
  end

  def content = JSON.parse(message)

  def error? = result.fetch("isError", false)

  def message = result.fetch("content").first.fetch("text")

  def result = JSON.parse(last_response.body).fetch("result")

  describe "list_tags" do
    before do
      create(:post, tags: %w[ruby])
      create(:project, tags: %w[ruby])
      create(:project, tags: %w[ruby cli])
      create(:tag, name: "unused")
      call_tool("list_tags")
    end

    def named(name) = content.fetch("tags").find { it.fetch("name") == name }

    it "lists every tag by name" do
      expect(content.fetch("tags").map { it.fetch("name") }).to eq(%w[cli ruby unused])
    end

    it "counts the records that carry each tag, by kind" do
      expect(named("ruby")).to include("count" => 3, "by_kind" => { "posts" => 1, "projects" => 2 })
    end

    it "counts a private tag by its private kinds" do
      create(:task, tags: %w[chores])
      call_tool("list_tags")

      expect(named("chores")).to include("count" => 1, "by_kind" => { "tasks" => 1 })
    end

    it "counts a tag nothing carries as zero" do
      expect(named("unused")).to include("count" => 0, "by_kind" => {})
    end
  end

  describe "save_tag" do
    it "adds a tag", :aggregate_failures do
      call_tool("save_tag", name: "Elixir", color: "mk-blue")

      expect(content).to include("name" => "elixir", "color" => "mk-blue")
      expect(tag_repo.all.map(&:name)).to eq(%w[elixir])
    end

    it "recolours a tag and keeps its name" do
      tag = create(:tag, name: "ruby", color: "mk-pink")
      call_tool("save_tag", id: tag.id, color: "mk-green")

      expect(tag_repo.by_id(tag.id)).to have_attributes(name: "ruby", color: "mk-green")
    end

    it "renames a tag and keeps its colour" do
      tag = create(:tag, name: "ruby", color: "mk-pink")
      call_tool("save_tag", id: tag.id, name: "crystal")

      expect(tag_repo.by_id(tag.id)).to have_attributes(name: "crystal", color: "mk-pink")
    end

    it "recolours a private tag" do
      tag = create(:tag, :private, name: "chores", color: "mk-pink")
      call_tool("save_tag", id: tag.id, color: "mk-green")

      expect(tag_repo.by_id(tag.id)).to have_attributes(name: "chores", color: "mk-green")
    end

    it "refuses a name another tag holds, with the reason the admin gives", :aggregate_failures do
      create(:tag, name: "ruby")
      call_tool("save_tag", name: "ruby")

      expect(error?).to be(true)
      expect(message).to eq("name: another tag already holds that name")
    end

    it "refuses a name that is not lowercase words joined by hyphens" do
      call_tool("save_tag", name: "two words")

      expect(message).to eq("name: a tag is lowercase words joined by hyphens")
    end

    it "refuses an ID no tag has" do
      call_tool("save_tag", id: 999_999, name: "ghost")

      expect(message).to eq("no tag has the ID 999999")
    end
  end

  describe "remove_tag" do
    it "removes a tag nothing carries" do
      tag = create(:tag)
      call_tool("remove_tag", id: tag.id)

      expect(tag_repo.all).to be_empty
    end

    it "removes a private tag nothing carries" do
      tag = create(:tag, :private)
      call_tool("remove_tag", id: tag.id)

      expect(tag_repo.all).to be_empty
    end

    it "keeps a tag a record carries, with the reason the admin gives", :aggregate_failures do
      create(:project, tags: %w[ruby])
      create(:post, tags: %w[ruby])
      call_tool("remove_tag", id: tag_repo.all.first.id)

      expect(message).to eq("kept: 2 records still carry it")
      expect(tag_repo.all.map(&:name)).to eq(%w[ruby])
    end

    it "refuses an ID no tag has" do
      call_tool("remove_tag", id: 999_999)

      expect(message).to eq("no tag has the ID 999999")
    end
  end
end
