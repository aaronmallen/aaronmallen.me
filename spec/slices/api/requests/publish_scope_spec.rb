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

    it "cannot change the body of a scheduled post", :aggregate_failures do
      post = create(:post, :scheduled, body: "as it was", published_at: Time.now + 86_400)

      expect(call_api(:patch, "/posts/#{post.id}", { body: "changed" })).to be_refused
      expect(Posts::Slice["repos.post_queries"].by_id(post.id).body).to eq("as it was")
    end

    it "cannot tag a published post", :aggregate_failures do
      post = create(:post, :published)

      expect(call_api(:post, "/posts/bulk/tag",
                      { ids: [create(:post, :draft).id, post.id], tag: "ruby" })).to be_refused
      expect(Posts::Slice["repos.post_queries"].by_id(post.id).tags).to be_empty
    end

    it "still tags a draft" do
      expect(call_api(:post, "/posts/bulk/tag", { ids: [create(:post, :draft).id], tag: "ruby" }).status).to eq(200)
    end

    it "cannot change the social card of a published post" do
      expect(call_api(:patch, "/posts/#{create(:post, :published).id}/seo", { og_title: "Loud" })).to be_refused
    end

    it "still changes the social card of a draft" do
      expect(call_api(:patch, "/posts/#{create(:post, :draft).id}/seo", { og_title: "Quiet" }).status).to eq(200)
    end

    it "cannot approve webmentions", :aggregate_failures do
      mention = create(:webmention)

      expect(call_api(:post, "/webmentions/bulk/approve", { ids: [mention.id] })).to be_refused
      expect(Social::Slice["repos.webmention_queries"].by_id(mention.id).status).to eq("pending")
    end

    it "cannot approve a webmention one at a time" do
      expect(call_api(:post, "/webmentions/#{create(:webmention).id}/moderate", { verdict: "approved" })).to be_refused
    end

    it "still ignores a webmention" do
      expect(call_api(:post, "/webmentions/#{create(:webmention).id}/moderate", { verdict: "ignored" }).status)
        .to eq(200)
    end

    it "cannot sync issues while a task rule files into a published board" do
      Tasks::Slice["operations.save_task_rule"].call({ pattern: "aaronmallen/*", tags: "", projects: [board.id] })

      expect(call_api(:post, "/tasks/issues/sync")).to be_refused
    end

    it "cannot sync issues while a synced task sits on a published board" do
      create(:task_source, task_id: on_board.id)

      expect(call_api(:post, "/tasks/issues/sync")).to be_refused
    end

    it "cannot sync issues while a published board tracks a repo" do
      create(:project, name: "Tracked", board_published: true, repo: "aaronmallen/aaronmallen.me")

      expect(call_api(:post, "/tasks/issues/sync")).to be_refused
    end

    it "still syncs issues when no published board is in reach" do
      connect_github_token
      create(:task_source)
      create(:project, :private, board_published: true, repo: "aaronmallen/aaronmallen.me")

      expect(call_api(:post, "/tasks/issues/sync").status).to eq(200)
    end
  end

  describe "a token with publish" do
    it "adds a public project" do
      expect(call_api(:post, "/projects", { name: "Open", visibility: "public" }, scopes: %w[write publish]).status)
        .to eq(201)
    end

    it "tags a published post" do
      body = { ids: [create(:post, :published).id], tag: "ruby" }

      expect(call_api(:post, "/posts/bulk/tag", body, scopes: %w[write publish]).status).to eq(200)
    end

    it "approves webmentions" do
      body = { ids: [create(:webmention).id] }

      expect(call_api(:post, "/webmentions/bulk/approve", body, scopes: %w[write publish]).status).to eq(200)
    end

    it "syncs issues while a synced task sits on a published board" do
      connect_github_token
      create(:task_source, task_id: on_board.id)

      expect(call_api(:post, "/tasks/issues/sync", {}, scopes: %w[write publish]).status).to eq(200)
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

    it "is refused an approved webmention, naming publish" do
      expect(mcp_text("moderate_webmention", id: create(:webmention).id, verdict: "approved"))
        .to eq("an approved webmention shows in public, so this change needs the publish scope")
    end

    it "is refused a sync that reaches a published board, naming publish" do
      create(:task_source, task_id: on_board.id)

      expect(mcp_text("sync_issues")).to eq("a published board shows in public, so this change needs the publish scope")
    end

    it "is refused a change to a scheduled post, naming publish" do
      post = create(:post, :scheduled, published_at: Time.now + 86_400)

      expect(mcp_text("update_post", id: post.id, title: "Loud"))
        .to eq("this blog post shows in public, so this change needs the publish scope")
    end

    it "is refused a comment on a task on a published board, naming publish" do
      expect(mcp_text("add_task_comment", id: on_board.id, body: "hello"))
        .to eq("a task on a published board shows in public, so this change needs the publish scope")
    end
  end
end
