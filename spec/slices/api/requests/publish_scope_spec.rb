# frozen_string_literal: true

RSpec.describe "Changes that show in public", type: :request do
  let(:board) { create(:project, name: "Doing It", board_published: true) }
  let(:jane) { create(:person, key: "jane") }

  def on_board(task = create(:task))
    Links::Slice["operations.link_records"].call("task", task.id, { other_kind: "project", other_id: board.id })
    task
  end

  def project_tag(project) = Projects::Slice["repos.project_queries"].by_id(project.id).tags.first

  def recurring(task) = Tasks::Slice["operations.set_task_cadence"].call(task.id, { cadence: "days", every: 2 }).value!

  def response_to(verb, path, body = {}, scopes: %w[read write])
    call_api(verb, path, body, token: api_token(scopes)).then { last_response }
  end

  def rule_into(project)
    fields = { pattern: "aaronmallen/*", tags: "", projects: [project.id] }
    Tasks::Slice["operations.save_task_rule"].call(fields).value!
  end

  def scheduled_social_post(text = "teh one", status: "scheduled")
    Social::Slice["repos.social_post_mutations"]
      .create_with_parts(parts: [text], posted_at: Time.now + 86_400, status:, targets: %w[mastodon])
  end

  def suggest(post) = Suggestions::Slice["repos.suggestion_mutations"].replace_for_post(post.id, [typo])

  def suggest_social(social_post)
    Suggestions::Slice["repos.suggestion_mutations"].replace_for_social_post(social_post.id, [typo.merge(part: 1)])
  end

  def tag_on(post) = Posts::Slice["repos.post_queries"].by_id(post.id).tags.first

  def typo = { original: "teh", replacement: "the", reason: "typo" }

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
      expect(response_to(:post, "/projects", { name: "Hush", visibility: "public" })).to be_refused
      expect(get("/projects/hush").status).to eq(404)
    end

    it "cannot make a private project public, and its page still answers 404", :aggregate_failures do
      project = create(:project, :private, name: "Hush", board_published: true)

      expect(response_to(:patch, "/projects/#{project.id}", { visibility: "public" })).to be_refused
      expect(get("/projects/hush").status).to eq(404)
    end

    it "cannot publish the board of a public project, and its page still answers 404", :aggregate_failures do
      project = create(:project, name: "Hush")

      expect(response_to(:patch, "/projects/#{project.id}", { board_published: true })).to be_refused
      expect(get("/projects/hush").status).to eq(404)
    end

    it "still changes a private project" do
      project = create(:project, :private)

      expect(response_to(:patch, "/projects/#{project.id}", { tagline: "quiet" }).status).to eq(200)
    end

    it "cannot upload a share" do
      expect(response_to(:post, "/shares", { data: "aGk=", filename: "a.txt" })).to be_refused
    end

    it "cannot upload a share group" do
      expect(response_to(:post, "/share_groups", { files: [{ data: "aGk=", filename: "a.txt" }] })).to be_refused
    end

    it "cannot group, move or ungroup shares" do
      paths = ["/shares/bulk/group", "/share_groups/1/files", "/share_groups/1/files/2/ungroup"]

      expect(paths.map { response_to(:post, it, { ids: [1, 2] }) }).to all(be_refused)
    end

    it "cannot rename a share, a share group or a file in a group" do
      changes = {
        "/shares/1" => { filename: "b.txt" }, "/share_groups/1" => { name: "Loud" },
        "/share_groups/1/files/2" => { filename: "b.txt" },
      }

      expect(changes.map { response_to(:patch, *it) }).to all(be_refused)
    end

    it "cannot change the body of a published post", :aggregate_failures do
      post = create(:post, :published, body: "as it was")

      expect(response_to(:patch, "/posts/#{post.id}", { body: "changed", edit_note: "why" })).to be_refused
      expect(Posts::Slice["repos.post_queries"].by_id(post.id).body).to eq("as it was")
    end

    it "still changes a draft" do
      post = create(:post, :draft)

      expect(response_to(:patch, "/posts/#{post.id}", { body: "changed" }).status).to eq(200)
    end

    it "cannot change a task on a published board" do
      expect(response_to(:patch, "/tasks/#{on_board.id}", { title: "changed" })).to be_refused
    end

    it "cannot comment on a task on a published board" do
      expect(response_to(:post, "/tasks/#{on_board.id}/comments", { body: "hello" })).to be_refused
    end

    it "cannot close a task on a published board" do
      expect(response_to(:post, "/tasks/#{on_board.id}/complete")).to be_refused
    end

    it "cannot put a task on a published board" do
      body = { other_kind: "project", other_id: board.id }

      expect(response_to(:post, "/links/task/#{create(:task).id}", body)).to be_refused
    end

    it "cannot take a task off a published board", :aggregate_failures do
      task = on_board

      expect(response_to(:delete, "/links/task/#{task.id}/project/#{board.id}")).to be_refused
      expect(Tasks::Slice["repos.task_queries"].public_board_slugs([task.id])).to eq(task.id => [board.slug])
    end

    it "cannot move a task off a published board into a private project" do
      body = { other_kind: "project", other_id: create(:project, :private).id }

      expect(response_to(:post, "/links/task/#{on_board.id}", body)).to be_refused
    end

    it "still links a task on no published board to a private project" do
      body = { other_kind: "project", other_id: create(:project, :private).id }

      expect(response_to(:post, "/links/task/#{create(:task).id}", body).status).to eq(201)
    end

    it "cannot add a task rule that files into a published board" do
      expect(response_to(:post, "/task_rules", { pattern: "aaronmallen/*", projects: [board.id] })).to be_refused
    end

    it "still adds a task rule that files into a private project" do
      body = { pattern: "aaronmallen/*", projects: [create(:project, :private).id] }

      expect(response_to(:post, "/task_rules", body).status).to eq(201)
    end

    it "cannot accept edits to a scheduled post", :aggregate_failures do
      post = create(:post, :scheduled, body: "teh cat sat", published_at: Time.now + 86_400)

      expect(response_to(:post, "/suggestions/#{suggest(post).id}/accept")).to be_refused
      expect(Posts::Slice["repos.post_queries"].by_id(post.id).body).to eq("teh cat sat")
    end

    it "still accepts edits to a draft" do
      post = create(:post, :draft, body: "teh cat sat")

      expect(response_to(:post, "/suggestions/#{suggest(post).id}/accept").status).to eq(200)
    end

    it "cannot rename a tag a published post carries", :aggregate_failures do
      tag = tag_on(create(:post, :published, tags: %w[ruby]))

      expect(response_to(:patch, "/tags/public/#{tag.id}", { name: "rails" })).to be_refused
      expect(Tags::Slice["repos.tag_queries"].find_in("public", tag.id).name).to eq("ruby")
    end

    it "still renames a tag only drafts carry" do
      tag = tag_on(create(:post, :draft, tags: %w[ruby]))

      expect(response_to(:patch, "/tags/public/#{tag.id}", { name: "rails" }).status).to eq(200)
    end

    it "cannot capture a task numbered on a published board, however the key is spelled" do
      create(:project, name: "Keyed", key: "PUB", board_published: true)

      ["PUB", "pub", " PUB "].each do |key|
        expect(response_to(:post, "/tasks", { title: "Loud", project: key })).to be_refused
      end
    end

    it "still captures a task numbered in a private project" do
      create(:project, :private, name: "Keyed", key: "HUSH", board_published: true)

      expect(response_to(:post, "/tasks", { title: "Quiet", project: "HUSH" }).status).to eq(201)
    end

    it "cannot point a task rule at a published board" do
      rule = rule_into(create(:project, :private))

      expect(response_to(:patch, "/task_rules/#{rule.id}", { projects: [board.id] })).to be_refused
    end

    it "cannot change a task rule that already files into a published board" do
      expect(response_to(:patch, "/task_rules/#{rule_into(board).id}", { pattern: "aaronmallen/blog" })).to be_refused
    end

    it "still moves a task rule off a published board into a private project" do
      body = { projects: [create(:project, :private).id] }

      expect(response_to(:patch, "/task_rules/#{rule_into(board).id}", body).status).to eq(200)
    end

    it "cannot resume a series whose task sits on a published board" do
      expect(response_to(:post, "/task_series/#{recurring(on_board).id}/resume")).to be_refused
    end

    it "still resumes a series whose task sits on no published board" do
      expect(response_to(:post, "/task_series/#{recurring(create(:task)).id}/resume").status).to eq(200)
    end

    it "cannot rename a tag a public project carries", :aggregate_failures do
      tag = project_tag(create(:project, tags: %w[ruby]))

      expect(response_to(:patch, "/tags/public/#{tag.id}", { name: "rails" })).to be_refused
      expect(Tags::Slice["repos.tag_queries"].find_in("public", tag.id).name).to eq("ruby")
    end

    it "still renames a tag only a private project carries" do
      tag = project_tag(create(:project, :private, tags: %w[ruby]))

      expect(response_to(:patch, "/tags/public/#{tag.id}", { name: "rails" }).status).to eq(200)
    end

    it "cannot accept edits to a scheduled social post", :aggregate_failures do
      social_post = scheduled_social_post

      expect(response_to(:post, "/suggestions/#{suggest_social(social_post).id}/accept")).to be_refused
      expect(Social::Slice["repos.social_post_queries"].by_id(social_post.id).parts.first.body).to eq("teh one")
    end

    it "cannot change a person a scheduled social post mentions, and the refusal names the post", :aggregate_failures do
      social_post = scheduled_social_post("hi @{jane}")
      response = response_to(:patch, "/people/#{jane.id}", { mastodon_handle: "@someone@else.social" })

      expect(response).to be_refused
      expect(JSON.parse(response.body).fetch("error_description")).to include("social post #{social_post.id}")
      expect(Social::Slice["repos.person_queries"].by_id(jane.id).mastodon_handle).to eq(jane.mastodon_handle)
    end

    it "cannot rename a person to a key a scheduled social post mentions" do
      scheduled_social_post("hi @{joan}")

      expect(response_to(:patch, "/people/#{jane.id}", { key: "joan" })).to be_refused
    end

    it "cannot add a person a scheduled social post mentions, and the refusal names the post", :aggregate_failures do
      social_post = scheduled_social_post("hi @{joan}")
      response = response_to(:post, "/people", { name: "Joan", key: "joan", mastodon_handle: "@joan@ruby.social" })

      expect(response).to be_refused
      expect(JSON.parse(response.body).fetch("error_description")).to include("social post #{social_post.id}")
      expect(Social::Slice["repos.person_queries"].by_keys(%w[joan])).to be_empty
    end

    it "still adds a person whose key only a draft social post mentions" do
      scheduled_social_post("hi @{joan}", status: "draft")
      body = { name: "Joan", key: "joan", mastodon_handle: "@joan@ruby.social" }

      expect(response_to(:post, "/people", body).status).to eq(201)
    end

    it "still changes a person no scheduled social post mentions" do
      scheduled_social_post("hi @{jane}", status: "draft")
      scheduled_social_post("hi @{janet}")

      expect(response_to(:patch, "/people/#{jane.id}", { name: "Jane Doe" }).status).to eq(200)
    end

    it "still changes a task on no published board" do
      expect(response_to(:patch, "/tasks/#{create(:task).id}", { title: "changed" }).status).to eq(200)
    end

    it "cannot add a work entry" do
      expect(response_to(:post, "/work_entries", { org: "Acme", role: "Engineer", from_year: 2020 })).to be_refused
    end

    it "cannot change the webmention settings" do
      expect(response_to(:patch, "/webmention_settings", { auto_approve_known_authors: true })).to be_refused
    end

    it "cannot change the body of a scheduled post", :aggregate_failures do
      post = create(:post, :scheduled, body: "as it was", published_at: Time.now + 86_400)

      expect(response_to(:patch, "/posts/#{post.id}", { body: "changed" })).to be_refused
      expect(Posts::Slice["repos.post_queries"].by_id(post.id).body).to eq("as it was")
    end

    it "cannot tag a published post", :aggregate_failures do
      post = create(:post, :published)
      body = { ids: [create(:post, :draft).id, post.id], tag: "ruby" }

      expect(response_to(:post, "/posts/bulk/tag", body)).to be_refused
      expect(Posts::Slice["repos.post_queries"].by_id(post.id).tags).to be_empty
    end

    it "still tags a draft" do
      expect(response_to(:post, "/posts/bulk/tag", { ids: [create(:post, :draft).id], tag: "ruby" }).status).to eq(200)
    end

    it "cannot change the social card of a published post" do
      expect(response_to(:patch, "/posts/#{create(:post, :published).id}/seo", { og_title: "Loud" })).to be_refused
    end

    it "still changes the social card of a draft" do
      expect(response_to(:patch, "/posts/#{create(:post, :draft).id}/seo", { og_title: "Quiet" }).status).to eq(200)
    end

    it "cannot approve webmentions", :aggregate_failures do
      mention = create(:webmention)

      expect(response_to(:post, "/webmentions/bulk/approve", { ids: [mention.id] })).to be_refused
      expect(Social::Slice["repos.webmention_queries"].by_id(mention.id).status).to eq("pending")
    end

    it "cannot approve a webmention one at a time" do
      mention = create(:webmention)

      expect(response_to(:post, "/webmentions/#{mention.id}/moderate", { verdict: "approved" })).to be_refused
    end

    it "still ignores a webmention" do
      expect(response_to(:post, "/webmentions/#{create(:webmention).id}/moderate", { verdict: "ignored" }).status)
        .to eq(200)
    end

    it "cannot sync issues while a task rule files into a published board" do
      Tasks::Slice["operations.save_task_rule"].call({ pattern: "aaronmallen/*", tags: "", projects: [board.id] })

      expect(response_to(:post, "/tasks/issues/sync")).to be_refused
    end

    it "cannot sync issues while a synced task sits on a published board" do
      create(:task_source, task_id: on_board.id)

      expect(response_to(:post, "/tasks/issues/sync")).to be_refused
    end

    it "cannot sync issues while a published board tracks a repo" do
      create(:project, name: "Tracked", board_published: true, repo: "aaronmallen/aaronmallen.me")

      expect(response_to(:post, "/tasks/issues/sync")).to be_refused
    end

    it "still syncs issues when no published board is in reach" do
      connect_github_token
      create(:task_source)
      create(:project, :private, board_published: true, repo: "aaronmallen/aaronmallen.me")

      expect(response_to(:post, "/tasks/issues/sync").status).to eq(200)
    end
  end

  describe "a token with publish" do
    it "adds a public project" do
      expect(response_to(:post, "/projects", { name: "Open", visibility: "public" }, scopes: %w[write publish]).status)
        .to eq(201)
    end

    it "tags a published post" do
      body = { ids: [create(:post, :published).id], tag: "ruby" }

      expect(response_to(:post, "/posts/bulk/tag", body, scopes: %w[write publish]).status).to eq(200)
    end

    it "approves webmentions" do
      body = { ids: [create(:webmention).id] }

      expect(response_to(:post, "/webmentions/bulk/approve", body, scopes: %w[write publish]).status).to eq(200)
    end

    it "syncs issues while a synced task sits on a published board" do
      connect_github_token
      create(:task_source, task_id: on_board.id)

      expect(response_to(:post, "/tasks/issues/sync", {}, scopes: %w[write publish]).status).to eq(200)
    end

    it "takes a task off a published board" do
      expect(response_to(:delete, "/links/task/#{on_board.id}/project/#{board.id}", {}, scopes: %w[write publish])
        .status).to eq(200)
    end

    it "adds a task rule that files into a published board" do
      body = { pattern: "aaronmallen/*", projects: [board.id] }

      expect(response_to(:post, "/task_rules", body, scopes: %w[write publish]).status).to eq(201)
    end

    it "accepts edits to a scheduled post" do
      post = create(:post, :scheduled, body: "teh cat sat", published_at: Time.now + 86_400)

      expect(response_to(:post, "/suggestions/#{suggest(post).id}/accept", {}, scopes: %w[write publish]).status)
        .to eq(200)
    end

    it "renames a tag a published post carries" do
      tag = tag_on(create(:post, :published, tags: %w[ruby]))

      expect(response_to(:patch, "/tags/public/#{tag.id}", { name: "rails" }, scopes: %w[write publish]).status)
        .to eq(200)
    end

    it "changes a task on a published board" do
      expect(response_to(:patch, "/tasks/#{on_board.id}", { title: "changed" }, scopes: %w[write publish]).status)
        .to eq(200)
    end

    it "captures a task numbered on a published board" do
      create(:project, name: "Keyed", key: "PUB", board_published: true)

      expect(response_to(:post, "/tasks", { title: "Loud", project: " pub " }, scopes: %w[write publish]).status)
        .to eq(201)
    end

    it "points a task rule at a published board" do
      rule = rule_into(create(:project, :private))

      expect(response_to(:patch, "/task_rules/#{rule.id}", { projects: [board.id] }, scopes: %w[write publish]).status)
        .to eq(200)
    end

    it "resumes a series whose task sits on a published board" do
      expect(response_to(:post, "/task_series/#{recurring(on_board).id}/resume", {}, scopes: %w[write publish]).status)
        .to eq(200)
    end

    it "renames a tag a public project carries" do
      tag = project_tag(create(:project, tags: %w[ruby]))

      expect(response_to(:patch, "/tags/public/#{tag.id}", { name: "rails" }, scopes: %w[write publish]).status)
        .to eq(200)
    end

    it "changes a person a scheduled social post mentions" do
      scheduled_social_post("hi @{jane}")

      expect(response_to(:patch, "/people/#{jane.id}", { name: "Jane Doe" }, scopes: %w[write publish]).status)
        .to eq(200)
    end

    it "adds a person whose key a scheduled social post mentions" do
      scheduled_social_post("hi @{joan}")
      body = { name: "Joan", key: "joan", mastodon_handle: "@joan@ruby.social" }

      expect(response_to(:post, "/people", body, scopes: %w[write publish]).status).to eq(201)
    end

    it "accepts edits to a scheduled social post" do
      id = suggest_social(scheduled_social_post).id

      expect(response_to(:post, "/suggestions/#{id}/accept", {}, scopes: %w[write publish]).status).to eq(200)
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

    it "is refused taking a task off a published board, naming publish" do
      expect(mcp_text("unlink_records", kind: "task", id: on_board.id, other_kind: "project", other_id: board.id))
        .to eq("a task on a published board shows in public, so this change needs the publish scope")
    end

    it "is refused a task rule that files into a published board, naming publish" do
      expect(mcp_text("save_task_rule", pattern: "aaronmallen/*", projects: [board.id]))
        .to eq("a published board shows in public, so this change needs the publish scope")
    end

    it "is refused accepting edits to a scheduled post, naming publish" do
      post = create(:post, :scheduled, body: "teh cat sat", published_at: Time.now + 86_400)

      expect(mcp_text("accept_suggestion_edits", suggestion_id: suggest(post).id))
        .to eq("this blog post shows in public, so this change needs the publish scope")
    end

    it "is refused renaming a tag a published post carries, naming publish" do
      tag = tag_on(create(:post, :published, tags: %w[ruby]))

      expect(mcp_text("save_tag", id: tag.id, scope: "public", name: "rails"))
        .to eq("a blog post with this tag shows in public, so this change needs the publish scope")
    end
  end
end
