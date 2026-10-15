# frozen_string_literal: true

RSpec.describe "Changes that show in public", type: :request do
  let(:board) { create(:project, name: "Doing It", board_published: true) }

  def call_api(verb, path, body = {}, scopes: %w[read write])
    headers = { "CONTENT_TYPE" => "application/json", "HTTP_AUTHORIZATION" => "Bearer #{mint(scopes)}" }
    public_send(verb, "/api/v1#{path}", JSON.generate(body), headers)
    last_response
  end

  def mint(scopes) = API::Slice["operations.mint_token"].call(name: "Terminal", scopes:).value!.fetch(:value)

  def on_board(task = create(:task))
    Links::Slice["operations.link_records"].call("task", task.id, { other_kind: "project", other_id: board.id })
    task
  end

  matcher :be_refused do
    match do |response|
      response.status == 403 &&
        response.headers["WWW-Authenticate"] == %(Bearer error="insufficient_scope", scope="publish") &&
        JSON.parse(response.body).fetch("error_description").include?("the publish scope")
    end

    failure_message { |response| "expected a refusal naming publish, got #{response.status} #{response.body}" }
  end

  describe "a token with read and write but not publish" do
    it "cannot add a public project, and its page answers 404", :aggregate_failures do
      expect(call_api(:post, "/projects", { name: "Hush", visibility: "public" })).to be_refused
      expect(get("/projects/hush").status).to eq(404)
    end

    it "cannot make a private project public, and its page still answers 404", :aggregate_failures do
      project = create(:project, :private, name: "Hush", board_published: true)

      expect(call_api(:patch, "/projects/#{project.id}", { visibility: "public" })).to be_refused
      expect(get("/projects/hush").status).to eq(404)
    end

    it "cannot publish the board of a public project, and its page still answers 404", :aggregate_failures do
      project = create(:project, name: "Hush")

      expect(call_api(:patch, "/projects/#{project.id}", { board_published: true })).to be_refused
      expect(get("/projects/hush").status).to eq(404)
    end

    it "still changes a private project" do
      project = create(:project, :private)

      expect(call_api(:patch, "/projects/#{project.id}", { tagline: "quiet" }).status).to eq(200)
    end

    it "cannot upload a share" do
      expect(call_api(:post, "/shares", { data: "aGk=", filename: "a.txt" })).to be_refused
    end

    it "cannot upload a share group" do
      expect(call_api(:post, "/share_groups", { files: [{ data: "aGk=", filename: "a.txt" }] })).to be_refused
    end

    it "cannot change the body of a published post", :aggregate_failures do
      post = create(:post, :published, body: "as it was")

      expect(call_api(:patch, "/posts/#{post.id}", { body: "changed", edit_note: "why" })).to be_refused
      expect(Posts::Slice["repos.post_queries"].by_id(post.id).body).to eq("as it was")
    end

    it "still changes a draft" do
      post = create(:post, :draft)

      expect(call_api(:patch, "/posts/#{post.id}", { body: "changed" }).status).to eq(200)
    end

    it "cannot change a task on a published board" do
      expect(call_api(:patch, "/tasks/#{on_board.id}", { title: "changed" })).to be_refused
    end

    it "cannot comment on a task on a published board" do
      expect(call_api(:post, "/tasks/#{on_board.id}/comments", { body: "hello" })).to be_refused
    end

    it "cannot close a task on a published board" do
      expect(call_api(:post, "/tasks/#{on_board.id}/complete")).to be_refused
    end

    it "cannot put a task on a published board" do
      body = { other_kind: "project", other_id: board.id }

      expect(call_api(:post, "/links/task/#{create(:task).id}", body)).to be_refused
    end

    it "still changes a task on no published board" do
      expect(call_api(:patch, "/tasks/#{create(:task).id}", { title: "changed" }).status).to eq(200)
    end

    it "cannot add a work entry" do
      expect(call_api(:post, "/work_entries", { org: "Acme", role: "Engineer", from_year: 2020 })).to be_refused
    end

    it "cannot change the webmention settings" do
      expect(call_api(:patch, "/webmention_settings", { auto_approve_known_authors: true })).to be_refused
    end
  end

  describe "a token with publish" do
    it "adds a public project" do
      expect(call_api(:post, "/projects", { name: "Open", visibility: "public" }, scopes: %w[write publish]).status)
        .to eq(201)
    end

    it "changes a task on a published board" do
      expect(call_api(:patch, "/tasks/#{on_board.id}", { title: "changed" }, scopes: %w[write publish]).status)
        .to eq(200)
    end
  end

  describe "an MCP client with read and write but not publish" do
    def mcp_scopes = %w[read write]

    it "is refused a public project, naming publish" do
      expect(mcp_call("save_project", name: "Hush", visibility: "public")).to eq(
        "content" => [{ "type" => "text",
                        "text" => "this project shows in public, so this change needs the publish scope" }],
        "isError" => true,
      )
    end

    it "is refused a comment on a task on a published board, naming publish" do
      expect(mcp_text("add_task_comment", id: on_board.id, body: "hello"))
        .to eq("a task on a published board shows in public, so this change needs the publish scope")
    end
  end
end
