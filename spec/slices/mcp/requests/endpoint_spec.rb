# frozen_string_literal: true

RSpec.describe "MCP endpoint", type: :request do
  let(:client) { mcp_create(:oauth_client) }
  let(:verifier) { MCP::OAuth::Secret.generate }

  def access_token = issued.fetch("access_token")

  def authorization_params
    {
      client_id: client.client_id,
      code_challenge: MCP::OAuth::PKCE.challenge(verifier),
      code_challenge_method: "S256",
      redirect_uri: client.redirect_uris.first,
      resource:,
      response_type: "code",
      scope: scopes,
      state: "state-from-claude",
    }
  end

  def call_tool(name, **arguments) = rpc("tools/call", { name:, arguments: })

  def card
    {
      og_title: "On the card",
      og_image_url: "https://example.com/card.png",
      canonical_url: "https://elsewhere.example/hello",
    }
  end

  def challenge = last_response.headers["WWW-Authenticate"]

  def clients = MCP::Slice["db.rom"].relations[:oauth_clients]

  def compose(status, *parts, posted_at: nil)
    social_post_repo.create_with_parts(parts:, posted_at:, status:, targets: %w[mastodon])
  end

  def connect
    sign_in_to_admin
    approve_authorization("/oauth/authorize?#{Rack::Utils.build_query(authorization_params)}")
    post "/oauth/token", token_params(Rack::Utils.parse_query(URI(last_response.location).query).fetch("code"))
    document
  end

  def content = JSON.parse(result.fetch("content").first.fetch("text"))

  def document = JSON.parse(last_response.body)

  def fetch_prompt(name, **arguments) = rpc("prompts/get", { name:, arguments: })

  def issued = @issued ||= connect

  def mcp_create(name, *traits, **) = Spec::DB::Factories[:mcp].create(name, *traits, **)

  def message = result.fetch("content").first.fetch("text")

  def metadata_url = "https://aaronmallen.me/.well-known/oauth-protected-resource/mcp"

  def offered = result.fetch("tools").map { it.fetch("name") }

  def prompt = result.fetch("messages").first

  def prompt_text = prompt.fetch("content").fetch("text")

  def read_tools
    %w[
      compose_announcement list_commits list_journal_entries list_messages list_posts list_projects list_social_posts
      list_sprints list_suggestions list_tags list_tasks list_webmentions list_work_entries
      read_activity read_analytics read_current_sprint read_journal_entry read_message read_post read_social_post
      read_sync_state read_task read_webmention_settings summarize_activity
    ]
  end

  def refresh_token = issued.fetch("refresh_token")

  def refusal = document.dig("error", "data")

  def resource = "https://aaronmallen.me/mcp"

  def result = document.fetch("result")

  def rpc(method, params = nil, id: 1, authorization: "Bearer #{access_token}", headers: {})
    sent = { "CONTENT_TYPE" => "application/json" }.merge(headers)
    sent["HTTP_AUTHORIZATION"] = authorization if authorization

    post "/mcp", JSON.generate({ jsonrpc: "2.0", id:, method:, params: }.compact), sent
  end

  def scopes = "read suggest write"

  def social_post_repo = Social::Slice["repos.social_post_repo"]

  def suggestion_repo = Suggestions::Slice["repos.suggestion_repo"]

  def token_params(code)
    {
      client_id: client.client_id,
      code:,
      code_verifier: verifier,
      grant_type: "authorization_code",
      redirect_uri: client.redirect_uris.first,
      resource:,
    }
  end

  def tokens = MCP::Slice["db.rom"].relations[:oauth_tokens]

  def write_tools
    %w[
      accept_suggestion_edits add_task_comment add_work_entry archive_project cancel_task capture_task complete_task
      create_journal_entry create_post create_social_post delete_journal_entry delete_post delete_social_post
      delete_task delete_work_entry drop_sprint import_commits link_tasks mark_message moderate_webmention
      move_project move_task plan_sprint publish_post reject_suggestion_edits remove_tag reopen_task reorder_task
      restore_project save_project save_tag save_task schedule_task send_social_post start_task
      unlink_task update_journal_entry update_post update_social_post update_webmention_settings write_post_seo
    ]
  end

  describe "a request with no token" do
    before { rpc("tools/list", authorization: nil) }

    it "refuses it" do
      expect(last_response.status).to eq(401)
    end

    it "points at the resource metadata" do
      expect(challenge).to eq(%(Bearer resource_metadata="#{metadata_url}"))
    end

    it "names no error, since no token was sent" do
      expect(challenge).not_to include("error=")
    end

    it "lets a browser client read the challenge" do
      expect(last_response.headers["Access-Control-Expose-Headers"]).to eq("WWW-Authenticate")
    end

    it "says what it wanted" do
      expect(document["error_description"]).to eq("this endpoint takes a bearer access token")
    end

    it "serves the metadata it points at" do
      get URI(challenge[/resource_metadata="([^"]+)"/, 1]).path

      expect(document["resource"]).to eq(resource)
    end
  end

  describe "a request whose Host somebody else picked" do
    before { rpc("tools/list", authorization: nil, headers: { "HTTP_X_FORWARDED_HOST" => "evil.example" }) }

    it "points at the configured resource metadata all the same" do
      expect(challenge).to include(%(resource_metadata="#{metadata_url}"))
    end

    it "names no endpoint on the host it was handed" do
      expect(challenge).not_to include("evil.example")
    end
  end

  describe "a token it refuses" do
    it "refuses a token it never issued" do
      rpc("tools/list", authorization: "Bearer #{MCP::OAuth::Secret.generate}")

      expect(last_response.status).to eq(401)
    end

    it "names the token as the problem" do
      rpc("tools/list", authorization: "Bearer #{MCP::OAuth::Secret.generate}")

      expect(document["error"]).to eq("invalid_token")
    end

    it "points at the resource metadata all the same" do
      rpc("tools/list", authorization: "Bearer #{MCP::OAuth::Secret.generate}")

      expect(challenge).to include(%(resource_metadata="#{metadata_url}"))
    end

    it "refuses a scheme it does not take" do
      rpc("tools/list", authorization: "Basic #{access_token}")

      expect(last_response.status).to eq(401)
    end

    it "refuses a refresh token" do
      rpc("tools/list", authorization: "Bearer #{refresh_token}")

      expect(last_response.status).to eq(401)
    end

    it "refuses an access token that expired" do
      token = access_token
      tokens.of_type("access").update(expires_at: Time.now - 1)
      rpc("tools/list", authorization: "Bearer #{token}")

      expect(last_response.status).to eq(401)
    end

    it "refuses an access token that was revoked" do
      token = access_token
      tokens.of_type("access").update(revoked_at: Time.now)
      rpc("tools/list", authorization: "Bearer #{token}")

      expect(last_response.status).to eq(401)
    end

    it "refuses a token issued for another resource" do
      token = access_token
      tokens.of_type("access").update(resource: "https://elsewhere.example/mcp")
      rpc("tools/list", authorization: "Bearer #{token}")

      expect(last_response.status).to eq(401)
    end

    it "refuses a token bound to no resource" do
      token = access_token
      tokens.of_type("access").update(resource: nil)
      rpc("tools/list", authorization: "Bearer #{token}")

      expect(last_response.status).to eq(401)
    end

    it "refuses a token whose client was revoked" do
      token = access_token
      clients.update(revoked_at: Time.now)
      rpc("tools/list", authorization: "Bearer #{token}")

      expect(last_response.status).to eq(401)
    end

    it "refuses a token the operator revoked from the admin" do
      token = access_token
      post "/admin/clients/#{clients.one[:id]}/revoke", _csrf_token: admin_csrf_token
      rpc("tools/list", authorization: "Bearer #{token}")

      expect(last_response.status).to eq(401)
    end
  end

  describe "a refresh" do
    def rotate(token)
      post "/oauth/token", { client_id: client.client_id, grant_type: "refresh_token", refresh_token: token, resource: }
      document
    end

    it "refuses the access token issued with the refresh token it spent" do
      token = access_token
      rotate(refresh_token)
      rpc("tools/list", authorization: "Bearer #{token}")

      expect(last_response.status).to eq(401)
    end

    it "answers the access token it hands out" do
      token = rotate(refresh_token).fetch("access_token")
      rpc("tools/list", authorization: "Bearer #{token}")

      expect(last_response.status).to eq(200)
    end

    it "keeps another pair the client holds working" do
      spent = refresh_token
      other = connect.fetch("access_token")
      rotate(spent)
      rpc("tools/list", authorization: "Bearer #{other}")

      expect(last_response.status).to eq(200)
    end
  end

  describe "a client that asks without naming a resource" do
    def resource = nil

    it "still answers it, since the code it was issued names this server" do
      rpc("tools/list")

      expect(last_response.status).to eq(200)
    end

    it "binds the token it issued to this server" do
      access_token

      expect(tokens.of_type("access").one[:resource]).to eq("https://aaronmallen.me/mcp")
    end
  end

  describe "the transport" do
    it "answers initialize" do
      rpc("initialize",
          { protocolVersion: "2025-06-18", capabilities: {}, clientInfo: { name: "Claude", version: "1" } })

      expect(result.dig("serverInfo", "name")).to eq("aaronmallen.me")
    end

    it "reports the version the app read at boot" do
      rpc("initialize",
          { protocolVersion: "2025-06-18", capabilities: {}, clientInfo: { name: "Claude", version: "1" } })

      expect(result.dig("serverInfo", "version")).to eq(Blog::Version::CURRENT)
    end

    it "tells the client it reads every record and makes every admin write" do
      rpc("initialize",
          { protocolVersion: "2025-06-18", capabilities: {}, clientInfo: { name: "Claude", version: "1" } })

      expect(result.fetch("instructions"))
        .to include("Read everything").and(include("publishing, sending and deleting included"))
    end

    it "takes a notification without answering" do
      rpc("notifications/initialized", id: nil)

      expect(last_response.status).to eq(202)
    end

    it "answers JSON" do
      rpc("tools/list")

      expect(last_response.headers["Content-Type"]).to eq("application/json")
    end

    it "answers only to POST" do
      get "/mcp"

      expect(last_response.status).to eq(405)
    end

    it "calls a body that is not JSON a parse error" do
      post "/mcp", "not json", "HTTP_AUTHORIZATION" => "Bearer #{access_token}"

      expect(document.dig("error", "code")).to eq(-32_700)
    end

    it "calls a body that opens like a batch but is not JSON a parse error" do
      post "/mcp", "[not json", "HTTP_AUTHORIZATION" => "Bearer #{access_token}"

      expect(document.dig("error", "code")).to eq(-32_700)
    end
  end

  describe "a batch" do
    def article = @article ||= create(:post, :published)

    def batch(*messages)
      sent = { "CONTENT_TYPE" => "application/json", "HTTP_AUTHORIZATION" => "Bearer #{access_token}" }

      post "/mcp", JSON.generate(messages), sent
    end

    def seo_call(id, og_title)
      { jsonrpc: "2.0", id:, method: "tools/call",
        params: { name: "write_post_seo", arguments: { id: article.id, og_title: } } }
    end

    it "refuses a batch of tool calls as an invalid request" do
      batch(seo_call(1, "First"), seo_call(2, "Second"))

      expect(document.dig("error", "code")).to eq(-32_600)
    end

    it "runs none of the tools in it" do
      batch(seo_call(1, "First"), seo_call(2, "Second"))

      expect(Posts::Slice["repos.post_repo"].by_id(article.id).og_title).to be_nil
    end

    it "refuses a batch of one" do
      batch(seo_call(1, "First"))

      expect(document.dig("error", "code")).to eq(-32_600)
    end

    it "refuses an empty batch" do
      batch

      expect(document.dig("error", "code")).to eq(-32_600)
    end
  end

  describe "the tools it offers" do
    before { rpc("tools/list") }

    it "offers reading, suggesting and writing, and nothing else" do
      expect(offered).to eq((read_tools + write_tools + %w[suggest_edits]).sort)
    end

    it "refuses a tool it does not have" do
      call_tool("rename_site", id: 1)

      expect(document.dig("error", "code")).to eq(-32_602)
    end
  end

  describe "a token that may only read" do
    def article = @article ||= create(:post, :published)

    def scopes = "read"

    def typo = { original: "teh", replacement: "the", reason: "typo" }

    it "offers the reading tools and nothing else" do
      rpc("tools/list")

      expect(offered).to eq(read_tools)
    end

    it "still reads a post" do
      call_tool("read_post", id: article.id)

      expect(content.fetch("id")).to eq(article.id)
    end

    it "refuses the social card write" do
      call_tool("write_post_seo", id: article.id, og_title: "On the card")

      expect(document.dig("error", "code")).to eq(-32_602)
    end

    it "answers the refusal as an MCP error rather than a 500" do
      call_tool("write_post_seo", id: article.id, og_title: "On the card")

      expect(last_response.status).to eq(200)
    end

    it "names the permission the write needed" do
      call_tool("write_post_seo", id: article.id, og_title: "On the card")

      expect(refusal).to eq(
        "write_post_seo needs the write permission, and this connection was never granted it. " \
        "Connect the app again to grant it",
      )
    end

    it "leaves the post as it stands" do
      call_tool("write_post_seo", id: article.id, og_title: "On the card")

      expect(Posts::Slice["repos.post_repo"].by_id(article.id).og_title).to be_nil
    end

    it "reads the activity feed" do
      call_tool("read_activity", from: "2026-01-01", to: "2026-12-31")

      expect(content).to include("from" => "2026-01-01", "to" => "2026-12-31")
    end

    it "reads the activity summary" do
      call_tool("summarize_activity", from: "2026-01-01", to: "2026-12-31")

      expect(content).to include("from" => "2026-01-01", "to" => "2026-12-31")
    end

    it "refuses a suggestion too" do
      call_tool("suggest_edits", target: "post", id: article.id, edits: [typo])

      expect(refusal).to include("suggest_edits needs the suggest permission")
    end

    it "stores no suggestion" do
      call_tool("suggest_edits", target: "post", id: article.id, edits: [typo])

      expect(suggestion_repo.for_post(article.id)).to be_nil
    end
  end

  describe "a token that may read and suggest" do
    def scopes = "read suggest"

    def typo = { original: "teh", replacement: "the", reason: "typo" }

    it "offers the suggesting tool" do
      rpc("tools/list")

      expect(offered).to eq((read_tools + %w[suggest_edits]).sort)
    end

    it "stores a suggestion" do
      post = create(:post, :draft, body: "teh cat sat")
      call_tool("suggest_edits", target: "post", id: post.id, edits: [typo])

      expect(suggestion_repo.for_post(post.id).edits).to have(1).item
    end

    it "refuses the social card write" do
      call_tool("write_post_seo", id: create(:post, :published).id, og_title: "On the card")

      expect(refusal).to include("write_post_seo needs the write permission")
    end
  end

  describe "a token that may read the activity feed" do
    def at(hour, on: today) = Blog::TimeZone.local_time(on.year, on.month, on.day, hour, 0)

    def entries = content.fetch("activity")

    def finish_with_comment
      create(:task_comment, task_id: create(:task, :done, completed_at: at(16)).id, created_at: at(10))
    end

    def kinds = entries.map { it.fetch("kind") }

    def month_ago = today - 30

    def names = entries.map { it.fetch("name") }

    def planning(article)
      create(:project)
      create(:sprint, sprint_date: today)
      suggestion_repo.replace_for_post(article.id, [typo])
    end

    def read_activity(from: month_ago, to: today, **arguments)
      call_tool("read_activity", from: from.to_s, to: to.to_s, **arguments)
    end

    def scopes = "read"

    def statements_to_read
      issued
      counting { read_activity }.size
    end

    def suggest_on(post_id, on: today)
      suggestion_repo.replace_for_post(post_id, [typo])
      Suggestions::Slice["db.rom"].relations[:suggestions].update(created_at: at(9, on:))
    end

    def today = Blog::TimeZone.today

    def typo = { original: "teh", replacement: "the", reason: "typo" }

    def whole_feed
      article = create(:post, :published, published_at: at(9))
      create(:commit, commit_date: today)
      create(:journal_entry, entry_date: today)
      create(:social_post, :posted, posted_at: at(12))
      create(:webmention, :approved, post_id: article.id, received_at: at(8))
      finish_with_comment
      planning(article)
    end

    it "names the window it read" do
      read_activity

      expect(content).to include("from" => month_ago.iso8601, "to" => today.iso8601)
    end

    it "gives every row its kind, date, time and name" do
      create(:commit, commit_date: today, commit_time: "14:30", message: "posts: add the view")
      read_activity

      expect(entries.first)
        .to include("kind" => "commit", "date" => today.iso8601, "time" => "14:30", "name" => "posts: add the view")
    end

    it "sends a commit's whole message, not its subject" do
      create(:commit, commit_date: today, message: "posts: add the view\n\nThe body says why it changed")
      read_activity

      expect(names).to eq(["posts: add the view\n\nThe body says why it changed"])
    end

    it "gives a commit its repository, sha and line counts" do
      create(:commit, commit_date: today, repo: "work/internal", sha: "a" * 40, additions: 12, deletions: 3)
      read_activity

      expect(entries.first)
        .to include("repo" => "work/internal", "sha" => "a" * 40, "additions" => 12, "deletions" => 3)
    end

    it "sends a journal entry" do
      create(:journal_entry, entry_date: today, body: "wrote the tool")
      read_activity

      expect(entries).to contain_exactly(include("kind" => "journal", "name" => "wrote the tool"))
    end

    it "sends a finished task with no type", :aggregate_failures do
      create(:task, :done, completed_at: at(16), title: "Clear the inbox")
      read_activity

      expect(entries.first).to include("kind" => "task", "name" => "Clear the inbox")
      expect(entries.first).not_to have_key("task_type")
    end

    it "leaves a canceled task out" do
      create(:task, :done, completed_at: at(16), title: "Clear the inbox")
      create(:task, :canceled, completed_at: at(17), title: "Drop the idea")
      read_activity

      expect(names).to eq(["Clear the inbox"])
    end

    describe "a comment on a task" do
      let(:task) { create(:task, title: "Clear the inbox", tags: %w[home]) }

      def comment(*traits, **attrs) = create(:task_comment, *traits, task_id: task.id, created_at: at(10), **attrs)

      it "sends a local comment with its text, its task's title and its task's id" do
        comment(body: "Down to ten")
        read_activity

        expect(entries).to contain_exactly(
          include("kind" => "comment", "name" => "Down to ten", "excerpt" => "Clear the inbox", "task_id" => task.id),
        )
      end

      it "sends a synced comment with its link" do
        synced = comment(:synced, body: "From the issue")
        read_activity

        expect(entries).to contain_exactly(
          include("kind" => "comment", "name" => "From the issue", "link" => synced.url),
        )
      end

      it "narrows to comments" do
        comment
        create(:task, :done, completed_at: at(16))
        read_activity(kinds: %w[comment])

        expect(kinds).to eq(%w[comment])
      end

      it "matches a comment by its task's tags" do
        comment(body: "Down to ten")
        create(:task_comment, body: "Elsewhere", created_at: at(10))
        read_activity(tags: %w[home])

        expect(names).to eq(["Down to ten"])
      end

      it "gives a comment its task's tags" do
        comment(body: "Down to ten")
        read_activity

        expect(entries).to contain_exactly(include("kind" => "comment", "tags" => %w[home]))
      end

      it "matches a comment by its text" do
        comment(body: "Down to ten")
        comment(body: "Still full")
        read_activity(text: "down to")

        expect(names).to eq(["Down to ten"])
      end
    end

    it "sends every kind the feed holds" do
      whole_feed
      read_activity

      expect(kinds).to match_array(Blog::Types::ActivityKind.values)
    end

    it "gives a project its name and link" do
      create(:project, name: "blog", url: "https://blog.example", repo: "aaronmallen/blog", tagline: "the site")
      read_activity

      expect(entries.first).to include("kind" => "project", "name" => "blog", "link" => "https://blog.example")
    end

    it "gives a project its repository, status and tagline" do
      create(:project, repo: "aaronmallen/blog", tagline: "the site")
      read_activity

      expect(entries.first).to include("repo" => "aaronmallen/blog", "status" => "active", "excerpt" => "the site")
    end

    it "sends a sprint on its day" do
      create(:sprint, sprint_date: today - 2)
      read_activity

      expect(entries).to contain_exactly(include("kind" => "sprint", "date" => (today - 2).iso8601, "time" => "00:00"))
    end

    it "names a suggestion on a post by the post and links to it" do
      suggest_on(create(:post, :draft, title: "Half done", slug: "half-done").id)
      read_activity

      expect(entries).to contain_exactly(
        include("kind" => "suggestion", "date" => today.iso8601, "name" => "Half done", "link" => "/writing/half-done"),
      )
    end

    it "names a suggestion on a social post by its first part" do
      social_post = compose("draft", "teh first part", "the second part")
      suggestion_repo.replace_for_social_post(social_post.id, [typo])
      read_activity

      expect(entries).to contain_exactly(include("kind" => "suggestion", "name" => "teh first part"))
    end

    it "reads no project, sprint or suggestion outside the window" do
      create(:project, created_at: at(9, on: today - 300))
      create(:sprint, sprint_date: today - 300)
      suggest_on(create(:post, :draft).id, on: today - 300)
      read_activity

      expect(entries).to be_empty
    end

    it "narrows to a kind it once left out" do
      whole_feed
      read_activity(kinds: %w[webmention sprint])

      expect(kinds).to contain_exactly("webmention", "sprint")
    end

    it "refuses a kind the feed does not hold" do
      read_activity(kinds: %w[meeting])

      expect(result.fetch("isError")).to be(true)
    end

    it "sends the newest row first" do
      create(:commit, commit_date: today - 2, message: "older")
      create(:commit, commit_date: today, message: "newer")
      read_activity

      expect(names).to eq(%w[newer older])
    end

    it "reads a range a year wide" do
      create(:commit, commit_date: today - 300, message: "long ago")
      read_activity(from: today - 365)

      expect(names).to eq(["long ago"])
    end

    it "reads nothing outside the window" do
      create(:commit, commit_date: today - 300)
      read_activity

      expect(entries).to be_empty
    end

    it "narrows to the kinds it is given" do
      create(:commit, commit_date: today)
      create(:journal_entry, entry_date: today)
      read_activity(kinds: %w[journal])

      expect(kinds).to eq(%w[journal])
    end

    it "narrows to the repositories it is given" do
      create(:commit, commit_date: today, repo: "aaronmallen/blog", message: "in blog")
      create(:commit, commit_date: today, repo: "aaronmallen/site", message: "in site")
      read_activity(repos: %w[aaronmallen/blog])

      expect(names).to eq(["in blog"])
    end

    it "keeps the commits of every repository it is given" do
      create(:commit, commit_date: today, repo: "aaronmallen/blog", message: "in blog")
      create(:commit, commit_date: today, repo: "aaronmallen/site", message: "in site")
      create(:commit, commit_date: today, repo: "aaronmallen/other", message: "in other")
      read_activity(repos: %w[aaronmallen/blog site])

      expect(names).to contain_exactly("in blog", "in site")
    end

    it "keeps what is not a commit when it is given two repositories" do
      create(:commit, commit_date: today, repo: "aaronmallen/blog", message: "in blog")
      create(:journal_entry, entry_date: today, body: "walked the dog")
      read_activity(repos: %w[aaronmallen/blog aaronmallen/site])

      expect(names).to contain_exactly("in blog", "walked the dog")
    end

    it "narrows to a repository named with capitals" do
      create(:commit, commit_date: today, repo: "aaronmallen/blog", message: "in blog")
      create(:commit, commit_date: today, repo: "aaronmallen/site", message: "in site")
      read_activity(repos: %w[aaronmallen/Blog])

      expect(names).to eq(["in blog"])
    end

    it "narrows to a repository named with capitals and no owner" do
      create(:commit, commit_date: today, repo: "aaronmallen/blog", message: "in blog")
      create(:commit, commit_date: today, repo: "aaronmallen/site", message: "in site")
      read_activity(repos: %w[Blog])

      expect(names).to eq(["in blog"])
    end

    it "narrows to the tags it is given" do
      create(:journal_entry, entry_date: today, body: "about the site", tags: %w[site])
      create(:journal_entry, entry_date: today, body: "about work", tags: %w[work])
      read_activity(tags: %w[site])

      expect(names).to eq(["about the site"])
    end

    it "narrows to a tag named with capitals" do
      create(:journal_entry, entry_date: today, body: "about the site", tags: %w[site])
      create(:journal_entry, entry_date: today, body: "about work", tags: %w[work])
      read_activity(tags: %w[Site])

      expect(names).to eq(["about the site"])
    end

    it "gives a journal entry its tags" do
      create(:journal_entry, entry_date: today, body: "slept well", tags: %w[health])
      read_activity

      expect(entries).to contain_exactly(include("kind" => "journal", "tags" => %w[health]))
    end

    it "gives a finished task its tags" do
      create(:task, :done, completed_at: at(16), tags: %w[home errands])
      read_activity

      expect(entries).to contain_exactly(include("kind" => "task", "tags" => %w[errands home]))
    end

    it "gives a published post its tags" do
      create(:post, :published, published_at: at(9), tags: %w[ruby])
      read_activity

      expect(entries).to contain_exactly(include("kind" => "post", "tags" => %w[ruby]))
    end

    it "leaves tags off a row that has none" do
      create(:journal_entry, entry_date: today)
      create(:commit, commit_date: today)
      read_activity

      expect(entries).to all(satisfy { !it.key?("tags") })
    end

    it "reads the tags of the whole window in the same statements as one row" do
      create(:journal_entry, entry_date: today, tags: %w[health])
      one = statements_to_read
      create(:journal_entry, entry_date: today - 1, tags: %w[work])
      create(:task, :done, completed_at: at(16), tags: %w[home])

      expect(statements_to_read).to eq(one)
    end

    it "narrows to the text it is given" do
      create(:commit, commit_date: today, message: "admin: add the view")
      create(:journal_entry, entry_date: today, body: "nothing to see")
      read_activity(text: "add the view")

      expect(kinds).to eq(%w[commit])
    end

    it "counts what it sent" do
      2.times { create(:commit, commit_date: today) }
      read_activity

      expect(content.fetch("count")).to eq(2)
    end

    it "calls an answer inside the cap whole" do
      create(:commit, commit_date: today)
      read_activity

      expect(content.fetch("partial")).to be(false)
    end

    it "gives no day to carry on from when it sent the whole window" do
      create(:commit, commit_date: today)
      read_activity

      expect(content).not_to have_key("continue_to")
    end

    it "refuses a day it cannot read" do
      call_tool("read_activity", from: "last tuesday", to: today.iso8601)

      expect(message).to eq("give from and to as days, such as 2026-01-01")
    end

    it "refuses a from that comes after its to" do
      call_tool("read_activity", from: today.iso8601, to: (today - 7).iso8601)

      expect(message).to eq("from comes after to")
    end

    it "refuses a call naming no window" do
      call_tool("read_activity")

      expect(result.fetch("isError")).to be(true)
    end

    describe "a window holding more than one answer" do
      before { stub_const("MCP::Tools::DayWindow::CAP", 2) }

      def three_days
        3.downto(1) { |days| create(:commit, commit_date: today - days, message: "commit #{days}") }
      end

      def watched_activity_query
        Activity::Slice["queries.activity_between"].tap do |query|
          allow(query).to receive(:call).and_call_original
          replace_component("activity.queries.activity_between", query)
        end
      end

      it "says the answer is partial" do
        three_days
        read_activity

        expect(content.fetch("partial")).to be(true)
      end

      it "sends the newest rows in the window" do
        three_days
        read_activity

        expect(names).to eq(["commit 1", "commit 2"])
      end

      it "gives the day to carry on from" do
        three_days
        read_activity

        expect(content.fetch("continue_to")).to eq((today - 3).iso8601)
      end

      it "carries on from that day with nothing repeated" do
        three_days
        read_activity
        read_activity(to: Date.iso8601(content.fetch("continue_to")))

        expect(names).to eq(["commit 3"])
      end

      it "finishes the window on the next ask" do
        three_days
        read_activity
        read_activity(to: Date.iso8601(content.fetch("continue_to")))

        expect(content.fetch("partial")).to be(false)
      end

      it "rounds a day out rather than splitting it" do
        3.times { |n| create(:commit, commit_date: today - 1, message: "commit #{n}") }
        read_activity

        expect(entries).to have(3).items
      end

      it "asks the database for no more rows than one answer needs" do
        query = watched_activity_query
        three_days
        read_activity

        expect(query).to have_received(:call).with(hash_including(limit: 3)).at_least(:once)
      end

      it "calls a window that rounds out to its oldest day whole" do
        3.times { create(:commit, commit_date: today - 1) }
        read_activity

        expect(content.fetch("partial")).to be(false)
      end
    end

    describe "the summary over the same range" do
      def busy_months = months.transform_values { |counts| counts.select { |_, count| count.positive? }.keys }

      def counted = content.fetch("kinds")

      def january = Date.new(2026, 1, 1)

      def march = Date.new(2026, 3, 31)

      def months = content.fetch("months")

      def none = Blog::Types::ActivityKind.values.to_h { [it, 0] }

      def repos = content.fetch("repos")

      def summarize(from: month_ago, to: today)
        call_tool("summarize_activity", from: from.to_s, to: to.to_s)
      end

      def winter = summarize(from: january, to: march)

      it "names the range it counted" do
        summarize

        expect(content).to include("from" => month_ago.iso8601, "to" => today.iso8601)
      end

      it "counts each kind in the range" do
        2.times { create(:commit, commit_date: today) }
        create(:journal_entry, entry_date: today)

        summarize

        expect(counted).to eq(none.merge("commit" => 2, "journal" => 1))
      end

      it "counts every kind the feed holds" do
        whole_feed
        summarize

        expect(counted).to eq(Blog::Types::ActivityKind.values.to_h { [it, 1] })
      end

      it "counts a project, a sprint and a suggestion in the month each happened" do
        create(:project, created_at: at(9, on: Date.new(2026, 1, 12)))
        create(:sprint, sprint_date: Date.new(2026, 2, 3))
        suggest_on(create(:post, :draft).id, on: Date.new(2026, 3, 4))
        winter

        expect(busy_months).to eq("2026-03" => %w[suggestion], "2026-02" => %w[sprint], "2026-01" => %w[project])
      end

      it "counts nothing outside the range" do
        create(:commit, commit_date: today - 300)
        summarize

        expect(counted.fetch("commit")).to eq(0)
      end

      it "counts each kind in the month it happened" do
        create(:commit, commit_date: Date.new(2026, 1, 5))
        create(:journal_entry, entry_date: Date.new(2026, 2, 7))
        winter

        expect(months).to eq("2026-02" => none.merge("journal" => 1), "2026-01" => none.merge("commit" => 1))
      end

      it "counts a finished task in the month it was finished" do
        create(:task, :done, completed_at: at(16, on: Date.new(2026, 2, 9)))
        winter

        expect(months).to eq("2026-02" => none.merge("task" => 1))
      end

      it "counts local and synced comments in the month each was made" do
        task = create(:task)
        create(:task_comment, task_id: task.id, created_at: at(10, on: Date.new(2026, 1, 12)))
        create(:task_comment, :synced, task_id: task.id, created_at: at(10, on: Date.new(2026, 2, 3)))
        winter

        expect(months).to eq("2026-02" => none.merge("comment" => 1), "2026-01" => none.merge("comment" => 1))
      end

      it "puts the newest month first" do
        create(:commit, commit_date: Date.new(2026, 1, 5))
        create(:commit, commit_date: Date.new(2026, 3, 5))

        winter

        expect(months.keys).to eq(%w[2026-03 2026-01])
      end

      it "leaves out a month with nothing in it" do
        create(:commit, commit_date: Date.new(2026, 1, 5))

        winter

        expect(months.keys).to eq(%w[2026-01])
      end

      it "totals the commits and the lines each repository took" do
        create(:commit, commit_date: today, repo: "aaronmallen/blog", additions: 10, deletions: 2)
        create(:commit, commit_date: today, repo: "aaronmallen/blog", additions: 5, deletions: 1)

        summarize

        expect(repos).to eq("aaronmallen/blog" => { "commits" => 2, "additions" => 15, "deletions" => 3 })
      end

      it "keeps one repository apart from another" do
        create(:commit, commit_date: today, repo: "aaronmallen/blog")
        create(:commit, commit_date: today, repo: "work/internal")

        summarize

        expect(repos.keys).to eq(["aaronmallen/blog", "work/internal"])
      end

      it "totals no repository for a kind that carries none" do
        create(:journal_entry, entry_date: today)
        summarize

        expect(repos).to be_empty
      end

      it "answers a year in one call" do
        12.times { |month| create(:commit, commit_date: today - (month * 30), message: "commit #{month}") }
        summarize(from: today - 365)

        expect(counted.fetch("commit")).to eq(12)
      end

      it "carries no row body" do
        create(:commit, commit_date: today, message: "posts: add the view")
        create(:journal_entry, entry_date: today, body: "wrote the tool")
        summarize(from: today - 365)

        expect(message).not_to include("posts: add the view", "wrote the tool")
      end

      it "refuses a day it cannot read" do
        call_tool("summarize_activity", from: "last tuesday", to: today.iso8601)

        expect(message).to eq("give from and to as days, such as 2026-01-01")
      end

      it "refuses a from that comes after its to" do
        summarize(from: today, to: today - 7)

        expect(message).to eq("from comes after to")
      end

      it "refuses a range longer than 366 days" do
        summarize(from: today - 366)

        expect(message).to eq("give a range of 366 days or fewer")
      end

      it "counts a range of 366 days" do
        summarize(from: today - 365)

        expect(content).to include("from" => (today - 365).iso8601)
      end

      it "refuses a call naming no range" do
        call_tool("summarize_activity")

        expect(result.fetch("isError")).to be(true)
      end

      it "refuses a kinds argument, since it counts every kind" do
        call_tool("summarize_activity", from: month_ago.to_s, to: today.to_s, kinds: %w[webmention])

        expect(result.fetch("isError")).to be(true)
      end
    end
  end

  describe "a token issued before a scope was stored on one" do
    def article = @article ||= create(:post, :published)

    def backfilled
      token = access_token
      tokens.of_type("access").update(scopes: Sequel.lit("DEFAULT"))
      token
    end

    it "carries reading and nothing else" do
      backfilled

      expect(tokens.of_type("access").one[:scopes]).to eq(%w[read])
    end

    it "still reads" do
      rpc("tools/list", authorization: "Bearer #{backfilled}")

      expect(offered).to eq(read_tools)
    end

    it "cannot write until it is granted again" do
      rpc("tools/call", { name: "write_post_seo", arguments: { id: article.id, og_title: "On the card" } },
          authorization: "Bearer #{backfilled}")

      expect(refusal).to include("Connect the app again")
    end

    it "leaves the post as it stands" do
      rpc("tools/call", { name: "write_post_seo", arguments: { id: article.id, og_title: "On the card" } },
          authorization: "Bearer #{backfilled}")

      expect(Posts::Slice["repos.post_repo"].by_id(article.id).og_title).to be_nil
    end
  end

  describe "list_posts" do
    it "lists blog posts in every status" do
      %i[draft scheduled published].each { |status| create(:post, status, title: status.to_s) }
      call_tool("list_posts")

      expect(content.fetch("posts").map { it.fetch("status") }).to contain_exactly("draft", "scheduled", "published")
    end

    def listed_draft(post)
      {
        "id" => post.id, "draft" => true, "published_at" => nil, "status" => "draft", "title" => post.title,
        "updated_at" => post.updated_at.utc.iso8601,
      }
    end

    it "gives each blog post its ID, title, status, publish time and update time" do
      post = create(:post, :draft, title: "A draft")
      call_tool("list_posts")

      expect(content.fetch("posts").first).to eq(listed_draft(post))
    end

    it "says which blog posts are drafts" do
      %i[draft scheduled published].each { |status| create(:post, status, title: status.to_s) }
      call_tool("list_posts")

      expect(content.fetch("posts").to_h { [it.fetch("title"), it.fetch("draft")] })
        .to eq("draft" => true, "scheduled" => false, "published" => false)
    end

    it "gives a published post the time it went out" do
      post = create(:post, :published)
      call_tool("list_posts")

      expect(content.fetch("posts").first.fetch("published_at")).to eq(post.published_at.utc.iso8601)
    end

    describe "over a range of days" do
      def day(offset) = Blog::TimeZone.today + offset

      def listed = content.fetch("posts").map { it.fetch("title") }

      def on(offset, title, status: :published, hour: 12)
        at = Blog::TimeZone.local_time(day(offset).year, day(offset).month, day(offset).day, hour)
        create(:post, status, title:, published_at: at)
      end

      it "keeps the posts whose publish time falls inside the days" do
        on(-10, "before")
        on(-5, "inside")
        on(-1, "after")
        call_tool("list_posts", from: day(-6).iso8601, to: day(-4).iso8601)

        expect(listed).to eq(%w[inside])
      end

      it "counts both days whole, in Chicago time" do
        on(-6, "first thing", hour: 0)
        on(-4, "last thing", hour: 23)
        call_tool("list_posts", from: day(-6).iso8601, to: day(-4).iso8601)

        expect(listed).to eq(["last thing", "first thing"])
      end

      it "keeps a scheduled post whose time is still to come" do
        on(3, "queued", status: :scheduled)
        call_tool("list_posts", from: day(1).iso8601)

        expect(listed).to eq(%w[queued])
      end

      it "reads a from alone as every day from then on" do
        on(-10, "old")
        on(-2, "new")
        call_tool("list_posts", from: day(-3).iso8601)

        expect(listed).to eq(%w[new])
      end

      it "reads a to alone as every day up to then" do
        on(-10, "old")
        on(-2, "new")
        call_tool("list_posts", to: day(-3).iso8601)

        expect(listed).to eq(%w[old])
      end

      it "drops a draft with no publish time" do
        create(:post, :draft, title: "undated")
        call_tool("list_posts", from: day(-30).iso8601)

        expect(listed).to be_empty
      end

      it "keeps a draft whose publish time falls inside the days" do
        on(-2, "dated draft", status: :draft)
        call_tool("list_posts", from: day(-3).iso8601)

        expect(content.fetch("posts")).to contain_exactly(include("title" => "dated draft", "draft" => true))
      end

      it "leaves the social posts alone" do
        compose("draft", "a draft")
        call_tool("list_posts", from: day(1).iso8601)

        expect(content.fetch("social_posts")).to have(1).item
      end

      it "refuses a day it cannot read" do
        call_tool("list_posts", from: "last tuesday")

        expect(message).to eq("give from and to as days, such as 2026-01-01")
      end

      it "refuses a from that comes after its to" do
        call_tool("list_posts", from: day(0).iso8601, to: day(-7).iso8601)

        expect(message).to eq("from comes after to")
      end
    end

    it "lists social posts that are drafts or scheduled" do
      compose("draft", "a draft")
      compose("scheduled", "queued up", posted_at: Time.now + 3600)
      call_tool("list_posts")

      expect(content.fetch("social_posts").map { it.fetch("status") }).to contain_exactly("draft", "scheduled")
    end

    it "leaves out social posts already sent" do
      compose("posted", "gone out", posted_at: Time.now - 3600)
      call_tool("list_posts")

      expect(content.fetch("social_posts")).to be_empty
    end

    it "previews the first part of a social post" do
      compose("draft", "first part", "second part")
      call_tool("list_posts")

      expect(content.fetch("social_posts").first.fetch("preview")).to eq("first part")
    end

    it "previews a social post with no parts as empty" do
      compose("draft")
      call_tool("list_posts")

      expect(content.fetch("social_posts").first.fetch("preview")).to eq("")
    end

    it "cuts a long preview short" do
      compose("draft", "a" * 200)
      call_tool("list_posts")

      expect(content.fetch("social_posts").first.fetch("preview")).to eq("#{'a' * 120}…")
    end

    it "reads a preview as one line" do
      compose("draft", "  Hello\n\n  wide   world  ")
      call_tool("list_posts")

      expect(content.fetch("social_posts").first.fetch("preview")).to eq("Hello wide world")
    end

    it "drops the trailing space before the mark" do
      compose("draft", "#{'a' * 119} bbb")
      call_tool("list_posts")

      expect(content.fetch("social_posts").first.fetch("preview")).to eq("#{'a' * 119}…")
    end

    it "keeps a family emoji whole where it cuts a preview" do
      compose("draft", "#{'a' * 119}👩‍👩‍👧‍👦 x")
      call_tool("list_posts")

      expect(content.fetch("social_posts").first.fetch("preview")).to eq("#{'a' * 119}👩‍👩‍👧‍👦…")
    end
  end

  describe "read_post" do
    it "gives the title and the markdown body" do
      post = create(:post, :draft, title: "Draft one", body: "# Heading\n\nsome words")
      call_tool("read_post", id: post.id)

      written = { "id" => post.id, "status" => "draft", "title" => "Draft one", "body" => "# Heading\n\nsome words" }

      expect(content).to eq(written.merge("og_title" => nil, "og_image_url" => nil, "canonical_url" => nil))
    end

    it "gives the social card fields the post carries" do
      call_tool("read_post", id: create(:post, :draft, **card).id)

      expect(content).to include(card.transform_keys(&:to_s))
    end

    it "reads a published post too" do
      post = create(:post, :published, title: "Out there")
      call_tool("read_post", id: post.id)

      expect(content.fetch("title")).to eq("Out there")
    end

    it "calls an unknown ID an error" do
      call_tool("read_post", id: 404)

      expect(result.fetch("isError")).to be(true)
    end

    it "says which ID it could not find" do
      call_tool("read_post", id: 404)

      expect(message).to eq("no blog post has the ID 404")
    end

    it "refuses an ID that is not a number" do
      call_tool("read_post", id: "one")

      expect(result.fetch("isError")).to be(true)
    end

    it "refuses a call with no ID" do
      call_tool("read_post")

      expect(result.fetch("isError")).to be(true)
    end
  end

  describe "read_social_post" do
    it "gives the parts in order" do
      social_post = compose("draft", "one", "two", "three")
      call_tool("read_social_post", id: social_post.id)

      expect(content.fetch("parts")).to eq(%w[one two three])
    end

    it "reads one that is scheduled" do
      social_post = compose("scheduled", "queued up", posted_at: Time.now + 3600)
      call_tool("read_social_post", id: social_post.id)

      expect(content.fetch("status")).to eq("scheduled")
    end

    it "does not read one already sent" do
      social_post = compose("posted", "gone out", posted_at: Time.now - 3600)
      call_tool("read_social_post", id: social_post.id)

      expect(result.fetch("isError")).to be(true)
    end

    it "says which ID it could not find" do
      call_tool("read_social_post", id: 404)

      expect(message).to eq("no unsent social post has the ID 404")
    end
  end

  describe "suggest_edits" do
    let(:typo) { { original: "teh", replacement: "the", reason: "typo" } }

    it "stores the edits as pending" do
      post = create(:post, :draft, body: "teh cat sat")
      call_tool("suggest_edits", target: "post", id: post.id, edits: [typo])

      expect(suggestion_repo.for_post(post.id).edits.map(&:status)).to eq(["pending"])
    end

    it "stores what each edit says" do
      post = create(:post, :draft, body: "teh cat sat")
      call_tool("suggest_edits", target: "post", id: post.id, edits: [typo])

      expect(suggestion_repo.for_post(post.id).edits.first)
        .to have_attributes(original: "teh", replacement: "the", reason: "typo")
    end

    it "says how many edits it stored" do
      post = create(:post, :draft, body: "teh cat sat")
      call_tool("suggest_edits", target: "post", id: post.id, edits: [typo])

      expect(content).to include("edits" => 1, "status" => "pending", "target" => "post")
    end

    it "leaves the post body alone" do
      post = create(:post, :draft, body: "teh cat sat")
      call_tool("suggest_edits", target: "post", id: post.id, edits: [typo])

      expect(Posts::Slice["repos.post_repo"].by_id(post.id).body).to eq("teh cat sat")
    end

    it "replaces the edits still waiting from an earlier call" do
      post = create(:post, :draft, body: "teh cat sat")
      call_tool("suggest_edits", target: "post", id: post.id, edits: [typo])
      later = [{ **typo, original: "sat", replacement: "slept" }]
      call_tool("suggest_edits", target: "post", id: post.id, edits: later)

      expect(suggestion_repo.for_post(post.id).edits.map(&:original)).to eq(["sat"])
    end

    it "leaves an edit already answered alone" do
      post = create(:post, :draft, body: "teh cat sat")
      call_tool("suggest_edits", target: "post", id: post.id, edits: [typo])
      answered = suggestion_repo.accept(suggestion_repo.for_post(post.id).edits.map(&:id)).first
      call_tool("suggest_edits", target: "post", id: post.id, edits: [typo])

      expect(Suggestions::Slice["relations.suggestion_edits"].by_pk(answered.id).one[:status]).to eq("accepted")
    end

    it "pays no mind to a part on a blog post edit" do
      post = create(:post, :draft, body: "teh cat sat")
      call_tool("suggest_edits", target: "post", id: post.id, edits: [{ **typo, part: 4 }])

      expect(suggestion_repo.for_post(post.id).edits.map(&:part)).to eq([nil])
    end

    it "stores edits for an unsent social post" do
      social_post = compose("draft", "teh first", "teh second")
      call_tool("suggest_edits", target: "social_post", id: social_post.id, edits: [{ **typo, part: 2 }])

      expect(suggestion_repo.for_social_post(social_post.id).edits.map(&:part)).to eq([2])
    end

    it "takes the first part when an edit names none" do
      social_post = compose("draft", "teh first", "teh second")
      call_tool("suggest_edits", target: "social_post", id: social_post.id, edits: [typo])

      expect(suggestion_repo.for_social_post(social_post.id).edits.map(&:part)).to eq([1])
    end

    it "leaves the social post parts alone" do
      social_post = compose("draft", "teh first")
      call_tool("suggest_edits", target: "social_post", id: social_post.id, edits: [typo])

      expect(social_post_repo.by_id(social_post.id).parts.map(&:body)).to eq(["teh first"])
    end

    it "calls an unknown blog post an error" do
      call_tool("suggest_edits", target: "post", id: 404, edits: [typo])

      expect(message).to eq("no blog post has the ID 404")
    end

    it "refuses a published blog post" do
      post = create(:post, :published, body: "teh cat sat")
      call_tool("suggest_edits", target: "post", id: post.id, edits: [typo])

      expect(message).to eq("blog post #{post.id} is published; suggest edits only on a draft or scheduled post")
    end

    it "marks a published blog post an error" do
      post = create(:post, :published, body: "teh cat sat")
      call_tool("suggest_edits", target: "post", id: post.id, edits: [typo])

      expect(result.fetch("isError")).to be(true)
    end

    it "stores nothing for a published blog post" do
      post = create(:post, :published, body: "teh cat sat")
      call_tool("suggest_edits", target: "post", id: post.id, edits: [typo])

      expect(suggestion_repo.for_post(post.id)).to be_nil
    end

    it "stores edits for a scheduled blog post" do
      post = create(:post, :scheduled, body: "teh cat sat")
      call_tool("suggest_edits", target: "post", id: post.id, edits: [typo])

      expect(suggestion_repo.for_post(post.id).edits.map(&:status)).to eq(["pending"])
    end

    it "calls an unknown social post an error" do
      call_tool("suggest_edits", target: "social_post", id: 404, edits: [typo])

      expect(message).to eq("no unsent social post has the ID 404")
    end

    it "does not touch a social post already sent" do
      social_post = compose("posted", "gone out", posted_at: Time.now - 3600)
      call_tool("suggest_edits", target: "social_post", id: social_post.id, edits: [typo])

      expect(result.fetch("isError")).to be(true)
    end

    it "calls an empty edit list an error" do
      post = create(:post, :draft)
      call_tool("suggest_edits", target: "post", id: post.id, edits: [])

      expect(message).to eq("give at least one edit")
    end

    it "calls a part the social post has not got an error" do
      social_post = compose("draft", "teh first")
      call_tool("suggest_edits", target: "social_post", id: social_post.id, edits: [{ **typo, part: 3 }])

      expect(message).to eq("social post #{social_post.id} has no part 3")
    end

    it "refuses a target it does not know" do
      post = create(:post, :draft)
      call_tool("suggest_edits", target: "journal_entry", id: post.id, edits: [typo])

      expect(result.fetch("isError")).to be(true)
    end

    it "refuses an edit carrying a property it does not know" do
      post = create(:post, :draft, body: "teh cat sat")
      call_tool("suggest_edits", target: "post", id: post.id, edits: [{ **typo, note: "by the way" }])

      expect(result.fetch("isError")).to be(true)
    end

    it "stores nothing from an edit carrying a property it does not know" do
      post = create(:post, :draft, body: "teh cat sat")
      call_tool("suggest_edits", target: "post", id: post.id, edits: [{ **typo, note: "by the way" }])

      expect(suggestion_repo.for_post(post.id)).to be_nil
    end

    it "refuses an edit with no reason" do
      post = create(:post, :draft)
      call_tool("suggest_edits", target: "post", id: post.id, edits: [{ original: "teh", replacement: "the" }])

      expect(result.fetch("isError")).to be(true)
    end

    it "names the field when an original holds nothing but space" do
      post = create(:post, :draft, body: "teh cat sat")
      call_tool("suggest_edits", target: "post", id: post.id, edits: [{ **typo, original: "   " }])

      expect(message).to eq("edit 1: original needs a character that is not a space")
    end

    it "names the field when a reason holds nothing but space" do
      post = create(:post, :draft, body: "teh cat sat")
      call_tool("suggest_edits", target: "post", id: post.id, edits: [{ **typo, reason: " " }])

      expect(message).to eq("edit 1: reason needs a character that is not a space")
    end

    it "answers a blank original as a tool error, not an internal one" do
      post = create(:post, :draft, body: "teh cat sat")
      call_tool("suggest_edits", target: "post", id: post.id, edits: [{ **typo, original: " " }])

      expect(document).not_to have_key("error")
    end

    it "marks a blank original an error" do
      post = create(:post, :draft, body: "teh cat sat")
      call_tool("suggest_edits", target: "post", id: post.id, edits: [{ **typo, original: " " }])

      expect(result.fetch("isError")).to be(true)
    end

    it "counts the edits when it names the one it turned away" do
      post = create(:post, :draft, body: "teh cat sat")
      call_tool("suggest_edits", target: "post", id: post.id, edits: [typo, { **typo, reason: "\t" }])

      expect(message).to eq("edit 2: reason needs a character that is not a space")
    end

    it "stores nothing when it turns a blank original away" do
      post = create(:post, :draft, body: "teh cat sat")
      call_tool("suggest_edits", target: "post", id: post.id, edits: [{ **typo, original: "   " }])

      expect(suggestion_repo.for_post(post.id)).to be_nil
    end

    it "says it stored nothing when the store fails for a reason it does not know" do
      post = create(:post, :draft, body: "teh cat sat")
      failing = instance_double(Suggestions::Operations::ReplacePostEdits, call: Dry::Monads::Failure(:unexpected))
      replace_component("suggestions.operations.replace_post_edits", failing)
      call_tool("suggest_edits", target: "post", id: post.id, edits: [typo])

      expect(message).to eq("could not store the edits")
    end

    it "keeps the edits an earlier call stored when a later one is blank" do
      post = create(:post, :draft, body: "teh cat sat")
      call_tool("suggest_edits", target: "post", id: post.id, edits: [typo])
      call_tool("suggest_edits", target: "post", id: post.id, edits: [{ **typo, original: "  " }])

      expect(suggestion_repo.for_post(post.id).edits.map(&:original)).to eq(["teh"])
    end

    %i[original reason replacement].each do |field|
      it "names the #{field} when it holds a NUL" do
        post = create(:post, :draft, body: "teh cat sat")
        call_tool("suggest_edits", target: "post", id: post.id, edits: [{ **typo, field => "t\u0000he" }])

        expect(message).to eq("edit 1: #{field} holds a control character")
      end

      it "stores nothing when the #{field} holds a NUL" do
        post = create(:post, :draft, body: "teh cat sat")
        call_tool("suggest_edits", target: "post", id: post.id, edits: [{ **typo, field => "t\u0000he" }])

        expect(suggestion_repo.for_post(post.id)).to be_nil
      end
    end

    it "answers a NUL as a tool error, not an internal one" do
      post = create(:post, :draft, body: "teh cat sat")
      call_tool("suggest_edits", target: "post", id: post.id, edits: [{ **typo, replacement: "t\u0000he" }])

      expect(result.fetch("isError")).to be(true)
    end

    it "names the field when a social post edit holds nothing but space" do
      social_post = compose("draft", "teh first")
      call_tool("suggest_edits", target: "social_post", id: social_post.id, edits: [{ **typo, reason: "  " }])

      expect(message).to eq("edit 1: reason needs a character that is not a space")
    end

    it "refuses more edits than one call may carry" do
      post = create(:post, :draft, body: "teh cat sat")
      call_tool("suggest_edits", target: "post", id: post.id, edits: Array.new(51) { typo })

      expect(result.fetch("isError")).to be(true)
    end

    it "says the ceiling it holds the edits to" do
      post = create(:post, :draft, body: "teh cat sat")
      call_tool("suggest_edits", target: "post", id: post.id, edits: Array.new(51) { typo })

      expect(message).to include("50")
    end

    it "refuses a reason longer than the ceiling" do
      post = create(:post, :draft, body: "teh cat sat")
      call_tool("suggest_edits", target: "post", id: post.id, edits: [{ **typo, reason: "a" * 201 }])

      expect(result.fetch("isError")).to be(true)
    end

    it "stores nothing when it turns away more edits than one call may carry" do
      post = create(:post, :draft, body: "teh cat sat")
      call_tool("suggest_edits", target: "post", id: post.id, edits: Array.new(51) { typo })

      expect(suggestion_repo.for_post(post.id)).to be_nil
    end
  end

  describe "the prompts it offers" do
    before { rpc("prompts/list") }

    it "offers proofreading and a report, and nothing else" do
      expect(result.fetch("prompts").map { it.fetch("name") }).to eq(%w[proofread report])
    end

    it "has the report take a start day and an end day" do
      expect(result.fetch("prompts").last.fetch("arguments").map { it.slice("name", "required") })
        .to eq([{ "name" => "from", "required" => true }, { "name" => "to", "required" => true }])
    end

    it "takes a target and an ID" do
      expect(result.fetch("prompts").first.fetch("arguments").map { it.fetch("name") }).to eq(%w[target id])
    end

    it "asks for both" do
      expect(result.fetch("prompts").first.fetch("arguments").map { it.fetch("required") }).to eq([true, true])
    end

    it "says what it does" do
      expect(result.fetch("prompts").first.fetch("description")).to include("grammar, spelling and punctuation")
    end

    it "refuses a prompt it does not have" do
      fetch_prompt("rewrite", target: "post", id: "1")

      expect(document.dig("error", "code")).to eq(-32_602)
    end
  end

  describe "proofread" do
    before { fetch_prompt("proofread", target: "post", id: "12") }

    it "names the post it proofreads" do
      expect(result.fetch("description")).to eq("Proofread blog post 12")
    end

    it "speaks as the user" do
      expect(prompt.fetch("role")).to eq("user")
    end

    it "tells Claude to read the post first" do
      expect(prompt_text).to include("Call read_post with the ID 12 and read its markdown body")
    end

    it "sends the fixes back through suggest_edits" do
      expect(prompt_text).to include('suggest_edits, with the target "post" and the ID 12.')
    end

    it "limits the fixes to grammar, spelling and punctuation" do
      expect(prompt_text).to include("Fix grammar, spelling and punctuation, and nothing else")
    end

    it "names what to leave alone" do
      expect(prompt_text)
        .to include("Leave the style, the tone, the word choice and the structure as they stand")
    end

    it "leaves code and markdown syntax out of it" do
      expect(prompt_text).to include("Skip code blocks, inline code and link targets")
    end

    it "asks for the original text word for word" do
      expect(prompt_text).to include("the original text copied from the body exactly as it stands")
    end

    it "asks for a reason with each fix" do
      expect(prompt_text).to include('a reason of a few words, such as "typo" or "subject-verb agreement"')
    end

    it "reads a social post by its parts" do
      fetch_prompt("proofread", target: "social_post", id: "12")

      expect(prompt_text).to include("Call read_social_post with the ID 12 and read its parts in order")
    end

    it "numbers the part each social post fix belongs to" do
      fetch_prompt("proofread", target: "social_post", id: "12")

      expect(prompt_text).to include("Give each fix the number of the part it belongs to, counting from 1")
    end

    it "names the social post it proofreads" do
      fetch_prompt("proofread", target: "social_post", id: "12")

      expect(result.fetch("description")).to eq("Proofread social post 12")
    end

    it "refuses a target it does not know" do
      fetch_prompt("proofread", target: "journal_entry", id: "12")

      expect(document.dig("error", "code")).to eq(-32_602)
    end

    it "says which targets it takes" do
      fetch_prompt("proofread", target: "journal_entry", id: "12")

      expect(document.dig("error", "message")).to include("target takes post or social_post")
    end

    it "refuses an ID that is not a number" do
      fetch_prompt("proofread", target: "post", id: "twelve")

      expect(document.dig("error", "code")).to eq(-32_602)
    end

    it "refuses a call with no ID" do
      fetch_prompt("proofread", target: "post")

      expect(document.dig("error", "code")).to eq(-32_602)
    end
  end

  describe "report" do
    def named_tools = prompt_text.scan(/\b(?:list|read|summarize)_[a-z_]+\b/).uniq

    before { fetch_prompt("report", from: "2026-01-01", to: "2026-03-31") }

    it "names the range it reports on" do
      expect(result.fetch("description")).to eq("Report on 2026-01-01 to 2026-03-31")
    end

    it "speaks as the user" do
      expect(prompt.fetch("role")).to eq("user")
    end

    it "starts with the shape of the range" do
      expect(prompt_text).to include("First call summarize_activity with from 2026-01-01 and to 2026-03-31")
    end

    it "reads the feed after the summary" do
      expect(prompt_text.index("read_activity")).to be > prompt_text.index("summarize_activity")
    end

    it "pages the feed until partial comes back false" do
      expect(prompt_text).to include("continue_to as to, and keep going until partial comes back false")
    end

    it "fills in what the feed leaves out" do
      expect(named_tools).to include("list_tasks", "list_projects", "read_analytics", "list_messages")
    end

    it "asks for the open tasks" do
      expect(prompt_text).to include("list_tasks with the statuses open and in_progress")
    end

    it "asks for the canceled tasks and counts them apart from the done ones", :aggregate_failures do
      expect(prompt_text).to include("list_tasks with the status canceled and from 2026-01-01 and to 2026-03-31")
      expect(prompt_text).to include("report them apart from the done ones")
    end

    it "names only tools the server offers" do
      named = named_tools
      rpc("tools/list")

      expect(offered).to include(*named)
    end

    it "leaves the writing to the agent" do
      expect(prompt_text).to include("The tools only hand back data, so the report is yours to write")
    end

    it "refuses a day it cannot read" do
      fetch_prompt("report", from: "January", to: "2026-03-31")

      expect(document.dig("error", "code")).to eq(-32_602)
    end

    it "refuses a start after the end" do
      fetch_prompt("report", from: "2026-04-01", to: "2026-03-31")

      expect(document.dig("error", "data")).to include("from comes after to")
    end

    it "refuses a call with no end" do
      fetch_prompt("report", from: "2026-01-01")

      expect(document.dig("error", "code")).to eq(-32_602)
    end
  end

  describe "write_post_seo" do
    def article = @article ||= create(:post, :published)

    def seo(id) = Posts::Slice["repos.post_repo"].by_id(id)

    it "sets every social card field it takes" do
      call_tool("write_post_seo", id: article.id, og_title: "On the card", og_image_url: "https://e.example/c.png")

      expect(seo(article.id))
        .to have_attributes(og_title: "On the card", og_image_url: "https://e.example/c.png")
    end

    it "offers no canonical URL to set" do
      rpc("tools/list")
      tool = result.fetch("tools").find { it.fetch("name") == "write_post_seo" }

      expect(tool.dig("inputSchema", "properties").keys).to contain_exactly("id", "og_image_url", "og_title")
    end

    it "leaves the canonical URL alone when a client sends one anyway" do
      call_tool("write_post_seo", id: article.id, canonical_url: "https://elsewhere.example/hello")

      expect(seo(article.id).canonical_url).to be_nil
    end

    it "names the canonical URL back when a client sends one" do
      call_tool("write_post_seo", id: article.id, canonical_url: "https://elsewhere.example/hello")

      expect(message).to include("canonical_url")
    end

    it "answers with what the post now carries" do
      call_tool("write_post_seo", id: article.id, og_title: "On the card")

      expect(content).to eq("id" => article.id, "canonical_url" => nil, "og_image_url" => nil,
                            "og_title" => "On the card")
    end

    it "keeps the fields the call leaves out" do
      call_tool("write_post_seo", id: article.id, og_title: "On the card")
      call_tool("write_post_seo", id: article.id, og_image_url: "https://example.com/card.png")

      expect(seo(article.id).og_title).to eq("On the card")
    end

    it "clears a field an empty string names" do
      call_tool("write_post_seo", id: article.id, og_title: "On the card")
      call_tool("write_post_seo", id: article.id, og_title: "")

      expect(seo(article.id).og_title).to be_nil
    end

    it "changes nothing else about the post" do
      before_write = seo(article.id).to_h
      call_tool("write_post_seo", id: article.id, og_title: "On the card")

      expect(seo(article.id).to_h.except(:og_title, :updated_at)).to eq(before_write.except(:og_title, :updated_at))
    end

    it "refuses an image that is not a URL" do
      call_tool("write_post_seo", id: article.id, og_image_url: "card.png")

      expect(result.fetch("isError")).to be(true)
    end

    it "names the field it could not read" do
      call_tool("write_post_seo", id: article.id, og_image_url: "card.png")

      expect(message).to include("og_image_url")
    end

    it "names a card title holding a NUL" do
      call_tool("write_post_seo", id: article.id, og_title: "On the\u0000card")

      expect(message).to eq("og_title holds a control character")
    end

    it "leaves the post alone when the card title holds a NUL" do
      call_tool("write_post_seo", id: article.id, og_title: "On the\u0000card")

      expect(seo(article.id).og_title).to be_nil
    end

    it "leaves the post alone when it refuses" do
      call_tool("write_post_seo", id: article.id, og_title: "On the card", og_image_url: "card.png")

      expect(seo(article.id).og_title).to be_nil
    end

    it "calls an unknown ID an error" do
      call_tool("write_post_seo", id: 404, og_title: "On the card")

      expect(message).to eq("no blog post has the ID 404")
    end

    it "says it saved nothing when the save fails for a reason it does not know" do
      failing = instance_double(Posts::Operations::SavePostSeo, call: Dry::Monads::Failure(:unexpected))
      replace_component("posts.operations.save_post_seo", failing)
      call_tool("write_post_seo", id: article.id, og_title: "On the card")

      expect(message).to eq("could not save the social card fields")
    end

    it "refuses a call with no ID" do
      call_tool("write_post_seo", og_title: "On the card")

      expect(result.fetch("isError")).to be(true)
    end
  end

  describe "a tool that crashes" do
    let(:agent) { Hanami.app["honeybadger.agent"] }
    let(:crash) { Sequel::DatabaseConnectionError.new("PG::ConnectionBad: connection to server at 10.0.0.2 failed") }

    def notices = @notices ||= []

    def og_title = @og_title ||= SecureRandom.hex

    def reported = JSON.generate(notices.map(&:as_json))

    before do
      failing = instance_double(Posts::Operations::SavePostSeo)
      allow(failing).to receive(:call).and_raise(crash)
      replace_component("posts.operations.save_post_seo", failing)
      allow(agent).to receive(:notify).and_call_original
      record = ->(build, *args) { build.call(*args).tap { notices << it } }
      allow(Honeybadger::Notice).to receive(:new).and_wrap_original(&record)
      call_tool("write_post_seo", id: 1, og_title:)
    end

    it "tells Honeybadger what the tool raised" do
      expect(agent).to have_received(:notify).with(crash)
    end

    it "builds one notice" do
      expect(notices).to have(1).item
    end

    it "gives the client the generic message" do
      expect(document.dig("error", "data")).to eq("Internal error calling tool write_post_seo")
    end

    it "keeps what the tool raised out of the answer" do
      expect(last_response.body).not_to include("10.0.0.2")
    end

    it "sends Honeybadger no token" do
      expect(reported).not_to include(access_token)
    end

    it "sends Honeybadger none of the request body" do
      expect(reported).not_to include(og_title)
    end
  end

  describe "a prompt that crashes" do
    let(:agent) { Hanami.app["honeybadger.agent"] }
    let(:crash) { RuntimeError.new("the template broke") }

    before do
      allow(MCP::Prompt::Message).to receive(:new).and_raise(crash)
      allow(agent).to receive(:notify).and_call_original
      fetch_prompt("proofread", target: "post", id: "12")
    end

    it "tells Honeybadger what the prompt raised" do
      expect(agent).to have_received(:notify).with(crash)
    end

    it "keeps what the prompt raised out of the answer" do
      expect(last_response.body).not_to include("the template broke")
    end
  end

  describe "a call the server refuses" do
    let(:agent) { Hanami.app["honeybadger.agent"] }

    def scopes = "read"

    before { allow(agent).to receive(:notify).and_call_original }

    it "sends Honeybadger nothing for a tool the token's scopes withhold" do
      call_tool("write_post_seo", id: 1, og_title: "On the card")

      expect(agent).not_to have_received(:notify)
    end

    it "sends Honeybadger nothing for a prompt argument it cannot read" do
      fetch_prompt("proofread", target: "essay", id: "12")

      expect(agent).not_to have_received(:notify)
    end

    it "sends Honeybadger nothing for a tool it does not have" do
      call_tool("rename_site", id: 1)

      expect(agent).not_to have_received(:notify)
    end
  end

  describe "an argument no tool names" do
    def enough_for(name)
      {
        "accept_suggestion_edits" => { suggestion_id: 1 },
        "add_task_comment" => { id: 1, body: "Blocked on review" },
        "add_work_entry" => { org: "Acme", role: "Engineer", from_year: 2019 },
        "archive_project" => { id: 1 },
        "cancel_task" => { id: 1 },
        "capture_task" => { title: "Email the accountant" },
        "complete_task" => { id: 1 },
        "compose_announcement" => { id: 1 },
        "create_journal_entry" => { body: "Wrote it down" },
        "create_post" => { title: "A draft" },
        "create_social_post" => { parts: ["Hello"], targets: ["mastodon"] },
        "delete_journal_entry" => { id: 1 },
        "delete_post" => { id: 1 },
        "delete_social_post" => { id: 1 },
        "delete_task" => { id: 1 },
        "delete_work_entry" => { id: 1 },
        "drop_sprint" => { id: 1 },
        "import_commits" => {},
        "link_tasks" => { id: 1, kind: "blocks", other_id: 2 },
        "list_commits" => { from: "2026-01-01", to: "2026-12-31" },
        "list_journal_entries" => { from: "2026-01-01", to: "2026-12-31" },
        "list_messages" => { from: "2026-01-01", to: "2026-12-31" },
        "list_posts" => {},
        "list_projects" => {},
        "list_social_posts" => { from: "2026-01-01", to: "2026-12-31" },
        "list_sprints" => {},
        "list_suggestions" => { from: "2026-01-01", to: "2026-12-31" },
        "list_tags" => { scope: "public" },
        "list_tasks" => {},
        "list_webmentions" => { from: "2026-01-01", to: "2026-12-31" },
        "list_work_entries" => { from: "2026-01-01", to: "2026-12-31" },
        "mark_message" => { id: 1, status: "read" },
        "moderate_webmention" => { id: 1, verdict: "spam" },
        "move_project" => { id: 1, direction: "up" },
        "move_task" => { id: 1, list: "next" },
        "plan_sprint" => { sprint_on: "2026-01-01" },
        "publish_post" => { id: 1 },
        "read_activity" => { from: "2026-01-01", to: "2026-12-31" },
        "read_analytics" => { from: "2026-01-01", to: "2026-12-31" },
        "read_current_sprint" => {},
        "read_journal_entry" => { id: 1 },
        "read_message" => { id: 1 },
        "read_post" => { id: 1 },
        "read_social_post" => { id: 1 },
        "read_sync_state" => {},
        "read_task" => { id: 1 },
        "read_webmention_settings" => {},
        "reject_suggestion_edits" => { suggestion_id: 1 },
        "remove_tag" => { id: 1, scope: "public" },
        "reopen_task" => { id: 1 },
        "reorder_task" => { id: 1, direction: "up" },
        "restore_project" => { id: 1 },
        "save_project" => { id: 1 },
        "save_tag" => { id: 1, scope: "public" },
        "save_task" => { id: 1 },
        "schedule_task" => { id: 1, sprint_on: "" },
        "send_social_post" => { id: 1 },
        "start_task" => { id: 1 },
        "suggest_edits" => { target: "post", id: 1, edits: [{ original: "teh", replacement: "the", reason: "typo" }] },
        "summarize_activity" => { from: "2026-01-01", to: "2026-12-31" },
        "unlink_task" => { id: 1, other_id: 2 },
        "update_journal_entry" => { id: 1 },
        "update_post" => { id: 1 },
        "update_social_post" => { id: 1 },
        "update_webmention_settings" => {},
        "write_post_seo" => { id: 1 },
      }.fetch(name)
    end

    def scopes = MCP::OAuth::Scope::ALL.join(MCP::OAuth::Scope::SEPARATOR)

    MCP::Protocol::Handler::TOOLS.map(&:name_value).each do |name|
      it "refuses #{name} rather than raising on it" do
        call_tool(name, **enough_for(name), stray: "x")

        expect(message).to include("stray")
      end
    end
  end

  it "changes nothing when it reads" do
    post = create(:post, :draft)
    call_tool("read_post", id: post.id)

    expect(Posts::Slice["repos.post_repo"].by_id(post.id).to_h).to eq(post.to_h)
  end

  it "notes when the client last called" do
    rpc("tools/list")

    expect(clients.one[:last_used_at]).to be_within(60).of(Time.now)
  end

  it "notes a call when the client last called more than five minutes ago" do
    issued
    clients.by_pk(client.id).update(last_used_at: Time.now - (6 * 60))
    rpc("tools/list")

    expect(clients.one[:last_used_at]).to be_within(60).of(Time.now)
  end

  it "leaves the last call alone when the client called within five minutes" do
    issued
    called = Time.now.floor - (4 * 60)
    clients.by_pk(client.id).update(last_used_at: called)
    rpc("tools/list")

    expect(clients.one[:last_used_at]).to eq(called)
  end

  it "leaves updated_at alone when it notes a call" do
    issued
    updated = Time.now.floor - (24 * 60 * 60)
    clients.by_pk(client.id).update(updated_at: updated)
    rpc("tools/list")

    expect(clients.one[:updated_at]).to eq(updated)
  end
end
