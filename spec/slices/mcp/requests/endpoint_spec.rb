# frozen_string_literal: true

RSpec.describe "MCP endpoint", type: :request do
  let(:client) { mcp_create(:oauth_client) }
  let(:verifier) { Blog::SecretToken.generate }

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

  def read_kinds
    {
      "compose_announcement" => "announcements",
      "list_api_tokens" => "API tokens",
      "list_attention" => "attention",
      "list_calendar" => "the calendar",
      "list_clients" => "MCP clients",
      "list_commits" => "commits",
      "list_decisions" => "decisions",
      "list_inbox" => "the inbox",
      "list_journal_entries" => "the journal",
      "list_links" => "record links",
      "list_messages" => "messages",
      "list_people" => "people",
      "list_posts" => "posts",
      "list_projects" => "projects",
      "list_saved_views" => "saved views",
      "list_social_posts" => "social posts",
      "list_sprints" => "sprints",
      "list_suggestions" => "suggestions",
      "list_tags" => "tags",
      "list_task_tag_rules" => "task tag rules",
      "list_tasks" => "tasks",
      "list_webmentions" => "webmentions",
      "list_work_entries" => "work history",
      "read_activity" => "activity feed",
      "read_analytics" => "analytics",
      "read_commit" => "commits",
      "read_current_sprint" => "sprints",
      "read_decision" => "decisions",
      "read_journal_entry" => "the journal",
      "read_message" => "messages",
      "read_person" => "people",
      "read_photo" => "photos",
      "read_post" => "posts",
      "read_project" => "projects",
      "read_review" => "the review",
      "read_saved_view" => "saved views",
      "read_social_post" => "social posts",
      "read_sync_state" => "the sync state",
      "read_tag" => "tags",
      "read_task" => "tasks",
      "read_time_report" => "the time report",
      "read_webmention" => "webmentions",
      "read_webmention_settings" => "webmentions and their settings",
      "read_work_entry" => "work history",
      "search" => "Search every kind",
      "search_accounts" => "accounts on Mastodon and Bluesky",
      "summarize_activity" => "activity feed",
    }
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

  def scopes = "read suggest write publish delete"

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
      rpc("tools/list", authorization: "Bearer #{Blog::SecretToken.generate}")

      expect(last_response.status).to eq(401)
    end

    it "names the token as the problem" do
      rpc("tools/list", authorization: "Bearer #{Blog::SecretToken.generate}")

      expect(document["error"]).to eq("invalid_token")
    end

    it "points at the resource metadata all the same" do
      rpc("tools/list", authorization: "Bearer #{Blog::SecretToken.generate}")

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
        .to include("Read everything").and(include("Make any change the admin makes"))
    end

    it "tells the client which permission grants publishing, sending and deleting" do
      rpc("initialize",
          { protocolVersion: "2025-06-18", capabilities: {}, clientInfo: { name: "Claude", version: "1" } })

      expect(result.fetch("instructions"))
        .to include("publish grants publishing posts and sending social posts")
        .and(include("delete grants every tool that removes a record for good"))
    end

    it "names a kind in the instructions for every read tool" do
      rpc("initialize",
          { protocolVersion: "2025-06-18", capabilities: {}, clientInfo: { name: "Claude", version: "1" } })

      expect(read_kinds.values.reject { result.fetch("instructions").include?(it) }).to be_empty
    end

    it "tells the client suggestions settle through the tools" do
      rpc("initialize",
          { protocolVersion: "2025-06-18", capabilities: {}, clientInfo: { name: "Claude", version: "1" } })

      expect(result.fetch("instructions"))
        .to include("accept_suggestion_edits").and(include("reject_suggestion_edits"))
    end

    it "titles the server after the whole site" do
      rpc("initialize",
          { protocolVersion: "2025-06-18", capabilities: {}, clientInfo: { name: "Claude", version: "1" } })

      expect(result.dig("serverInfo", "title")).to eq("#{Hanami.app['settings'].owner[:name]}'s site")
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

    it "names a read tool in search for every kind it finds" do
      description = result.fetch("tools").find { it.fetch("name") == "search" }.fetch("description")
      readers = Blog::Types::SearchKind.values.to_h { [it, description[/\b#{it}: (read_\w+)/, 1]] }

      expect(readers.values - read_kinds.keys).to be_empty
    end
  end

  describe "a token that may only read" do
    def article = @article ||= create(:post, :published)

    def scopes = "read"

    def typo = { original: "teh", replacement: "the", reason: "typo" }

    it "offers the reading tools and nothing else" do
      rpc("tools/list")

      expect(offered).to eq(read_kinds.keys.sort)
    end

    it "still reads a post" do
      call_tool("read_post", id: article.id)

      expect(content.fetch("id")).to eq(article.id)
    end

    it "still lists decisions" do
      decision = create(:decision)
      call_tool("list_decisions")

      expect(content.fetch("decisions").map { it.fetch("id") }).to eq([decision.id])
    end

    it "still reads a decision" do
      decision = create(:decision)
      call_tool("read_decision", id: decision.id)

      expect(content.fetch("id")).to eq(decision.id)
    end

    it "refuses the social card write" do
      call_tool("write_post_seo", id: article.id, og_title: "On the card")

      expect(document.dig("error", "code")).to eq(-32_602)
    end

    it "answers the refusal as an MCP error rather than a 500" do
      call_tool("write_post_seo", id: article.id, og_title: "On the card")

      expect(last_response.status).to eq(200)
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

      expect(offered).to eq([*read_kinds.keys, "suggest_edits"].sort)
    end

    it "stores a suggestion" do
      post = create(:post, :draft, body: "teh cat sat")
      call_tool("suggest_edits", target: "post", id: post.id, edits: [typo])

      expect(suggestion_repo.for_post(post.id).edits).to have(1).item
    end
  end

  describe "a token that may read the activity feed" do
    def at(hour, on: today) = Blog::TimeZone.local_time(on.year, on.month, on.day, hour, 0)

    def deciding
      decision = create(:decision)
      create(:decision_event, decision_id: decision.id, created_at: at(11))
      create(:decision_comment, decision_id: decision.id, created_at: at(11))
    end

    def entries = content.fetch("activity")

    def finish_with_comment
      create(:task_comment, task_id: create(:task, :done, completed_at: at(16)).id, created_at: at(10))
    end

    def kinds = entries.map { it.fetch("kind") }

    def marked(text) = { "untrusted" => true, "text" => text }

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
      work_on_tasks
      deciding
      planning(article)
    end

    def work_on_tasks
      finish_with_comment
      create(:work_session, started_at: at(9), ended_at: at(10))
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

    it "gives each row the ID its kind's read tool takes" do
      commit = create(:commit, commit_date: today)
      entry = create(:journal_entry, entry_date: today)
      read_activity

      expect(entries.to_h { [it.fetch("kind"), it.fetch("source_id")] })
        .to eq("commit" => commit.id, "journal" => entry.id)
    end

    it "opens the record a row names with its kind's read tool" do
      create(:commit, commit_date: today, sha: "b" * 40)
      read_activity
      call_tool("read_commit", id: entries.first.fetch("source_id"))

      expect(content).to include("sha" => "b" * 40)
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

        shown = { "kind" => "comment", "name" => marked("Down to ten"), "excerpt" => "Clear the inbox" }

        expect(entries).to contain_exactly(include(shown.merge("task_id" => task.id)))
      end

      it "sends a synced comment with its link" do
        synced = comment(:synced, body: "From the issue")
        read_activity

        expect(entries).to contain_exactly(
          include("kind" => "comment", "name" => marked("From the issue"), "link" => synced.url),
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

        expect(names).to eq([marked("Down to ten")])
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

        expect(names).to eq([marked("Down to ten")])
      end
    end

    describe "a work session" do
      let(:task) { create(:task, :in_progress, title: "Clear the inbox", tags: %w[home]) }

      def event(kind, **columns)
        create(:task_event, task_id: task.id, kind:, tag_name: nil, occurred_at: at(9), **columns)
      end

      def session(started, ended) = create(:work_session, task_id: task.id, started_at: started, ended_at: ended)

      it "sends a closed session with its task's title, its task's id and how long it ran" do
        session(at(9), at(10) + 1800)
        read_activity

        expect(entries).to contain_exactly(
          include("kind" => "session", "name" => "Clear the inbox", "task_id" => task.id, "worked_seconds" => 5400),
        )
      end

      it "sends a session that crosses midnight on the day it started" do
        session(at(23, on: today - 2), at(1, on: today - 1))
        read_activity

        expect(entries).to contain_exactly(
          include("kind" => "session", "date" => (today - 2).iso8601, "time" => "23:00"),
        )
      end

      it "leaves out a session that is still running" do
        create(:work_session, task_id: task.id, started_at: at(9, on: today - 1))
        read_activity

        expect(entries).to be_empty
      end

      it "gives a session its task's tags" do
        session(at(9), at(10))
        read_activity

        expect(entries).to contain_exactly(include("kind" => "session", "tags" => %w[home]))
      end

      it "leaves out the task's moves, tag changes and status changes" do
        event("tagged", tag_name: "home")
        event("status_changed", from_status: "open", to_status: "in_progress")
        event("moved", from_list: "next", to_list: "someday")
        read_activity

        expect(entries).to be_empty
      end
    end

    describe "a decision" do
      let(:decision) { create(:decision, title: "Pick a queue", tags: %w[infra]) }
      let(:option) { create(:decision_option, decision_id: decision.id, title: "Sidekiq") }

      def comment(**attrs) = create(:decision_comment, decision_id: decision.id, created_at: at(11), **attrs)

      def event(kind, **attrs) = create(:decision_event, decision_id: decision.id, kind:, created_at: at(10), **attrs)

      def tagged_rows = entries.map { it.values_at("kind", "decision_id", "tags") }

      it "sends each event with the decision's title, what happened and the decision's id" do
        event("opened")
        read_activity

        expect(entries).to contain_exactly(
          include("kind" => "decision", "name" => "Pick a queue", "status" => "opened", "decision_id" => decision.id),
        )
      end

      it "sends the reason as the excerpt" do
        event("resolved", option_id: option.id, reason: "It already runs")
        read_activity

        expect(entries).to contain_exactly(include("status" => "resolved", "excerpt" => "It already runs"))
      end

      it "sends the option's title when the event has no reason or note" do
        event("option_added", option_id: option.id)
        read_activity

        expect(entries).to contain_exactly(include("status" => "option_added", "excerpt" => "Sidekiq"))
      end

      it "sends a comment with its text and the decision's title" do
        comment(body: "Ask ops first")
        read_activity

        expect(entries).to contain_exactly(
          include("kind" => "decision_comment", "name" => "Ask ops first", "excerpt" => "Pick a queue"),
        )
      end

      it "gives a comment its decision's id" do
        comment
        read_activity

        expect(entries).to contain_exactly(include("kind" => "decision_comment", "decision_id" => decision.id))
      end

      it "matches events and comments by the decision's tags" do
        event("opened")
        comment
        create(:decision_event, kind: "opened", created_at: at(12))
        read_activity(tags: %w[infra])

        expect(tagged_rows).to match_array(%w[decision decision_comment].map { [it, decision.id, %w[infra]] })
      end

      it "narrows to decision events" do
        event("opened")
        comment
        read_activity(kinds: %w[decision])

        expect(kinds).to eq(%w[decision])
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

    it "gives a row that has no tags an empty list" do
      create(:journal_entry, entry_date: today)
      create(:commit, commit_date: today)
      read_activity

      expect(entries.map { it.fetch("tags") }).to eq([[], []])
    end

    it "reads the tags of the whole window in the same statements as one row" do
      create(:task, :done, completed_at: at(16), tags: %w[home])
      one = statements_to_read
      [today, today - 1].each { create(:journal_entry, entry_date: it, tags: %w[health work]) }
      create(:task, :done, completed_at: at(15), tags: %w[errands])

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
      before { stub_const("Blog::DayWindow::CAP", 2) }

      def three_days
        3.downto(1) { |days| create(:commit, commit_date: today - days, message: "commit #{days}") }
      end

      def watched_activity_repo
        Activity::Slice["repos.activity_queries"].tap do |repo|
          allow(repo).to receive(:between).and_call_original
          replace_component("activity.repos.activity_queries", repo)
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
        repo = watched_activity_repo
        three_days
        read_activity

        expect(repo).to have_received(:between).with(hash_including(limit: 3)).at_least(:once)
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

      expect(offered).to eq(read_kinds.keys.sort)
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
        "id" => post.id, "draft" => true, "published_at" => nil, "slug" => post.slug, "status" => "draft",
        "tags" => [], "title" => post.title, "updated_at" => post.updated_at.utc.iso8601, "word_count" => 0,
        "views" => 0, "visitors" => 0, "readers" => 0, "read_throughs" => 0, "webmentions_received" => 0,
      }
    end

    it "gives each blog post its ID, slug, tags, title, status, times, words and readership" do
      post = create(:post, :draft, title: "A draft", body: "")
      call_tool("list_posts")

      expect(content.fetch("posts").first).to eq(listed_draft(post))
    end

    it "gives each blog post its tags" do
      post = create(:post, :draft)
      Posts::Slice["repos.post_repo"].replace_tags(post.id, %w[ruby web])
      call_tool("list_posts")

      expect(content.fetch("posts").first.fetch("tags")).to eq(%w[ruby web])
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
      call_tool("suggest_edits", target: "post", id: 999_999, edits: [typo])

      expect(message).to eq("no blog post has the ID 999999")
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
      call_tool("suggest_edits", target: "social_post", id: 999_999, edits: [typo])

      expect(message).to eq("no unsent social post has the ID 999999")
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

    it "names the field when an original holds nothing but Unicode spaces" do
      post = create(:post, :draft, body: "teh cat sat")
      call_tool("suggest_edits", target: "post", id: post.id, edits: [{ **typo, original: "\u2003\u3000" }])

      expect(message).to eq("edit 1: original needs a character that is not a space")
    end

    it "names the field when a reason holds nothing but Unicode spaces" do
      post = create(:post, :draft, body: "teh cat sat")
      call_tool("suggest_edits", target: "post", id: post.id, edits: [{ **typo, reason: "\u2003\u3000" }])

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

    it "refuses a range longer than 366 days", :aggregate_failures do
      fetch_prompt("report", from: "2024-01-01", to: "2025-01-01")

      expect(document.dig("error", "code")).to eq(-32_602)
      expect(document.dig("error", "data")).to include("give a range of 366 days or fewer")
    end

    it "reports on a range of 366 days" do
      fetch_prompt("report", from: "2024-01-01", to: "2024-12-31")

      expect(result.fetch("description")).to eq("Report on 2024-01-01 to 2024-12-31")
    end

    it "refuses a call with no end" do
      fetch_prompt("report", from: "2026-01-01")

      expect(document.dig("error", "code")).to eq(-32_602)
    end
  end

  describe "upload_photo" do
    let(:stored) { {} }

    def comment(size) = "\xFF\xFE".b + [size + 2].pack("n") + ("\0" * size)

    def padded(bytes, megabytes)
      segments = Array.new((megabytes * 1024 * 1024 / 65_533) + 1) { comment(65_531) }
      bytes.byteslice(0, 2) + segments.join + bytes.byteslice(2..)
    end

    def photo = padded(Hanami.app.root.join("spec/fixtures/photos/rotated_with_gps.jpg").binread, 2)

    before do
      connect_media_store
      stub_request(:put, %r{\Ahttps://store\.example(?::443)?/photos/}).to_return do |request|
        stored[File.basename(request.uri.path)] = request.body
        { status: 200 }
      end
    end

    it "stores a photo of 2 MB and answers its reference", :aggregate_failures do
      call_tool("upload_photo", data: Base64.strict_encode64(photo), filename: "photo.jpg")
      row = Media::Slice["relations.photos"].one

      expect(photo.bytesize).to be > 2 * 1024 * 1024
      expect(stored.keys).to contain_exactly(end_with(".jpg"))
      expect(content).to eq("url" => Blog::Site.url("/media/#{row[:key]}"), "width" => 20, "height" => 40)
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
      call_tool("write_post_seo", id: 999_999, og_title: "On the card")

      expect(message).to eq("no blog post has the ID 999999")
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
        "add_decision_comment" => { id: 1, body: "Leaning on Sidekiq" },
        "add_decision_option" => { id: 1, title: "Sidekiq" },
        "add_task_comment" => { id: 1, body: "Blocked on review" },
        "add_work_entry" => { org: "Acme", role: "Engineer", from_year: 2019 },
        "approve_webmentions" => { ids: [1] },
        "archive_project" => { id: 1 },
        "cancel_task" => { id: 1 },
        "cancel_tasks" => { ids: [1] },
        "capture_task" => { title: "Email the accountant" },
        "complete_task" => { id: 1 },
        "complete_tasks" => { ids: [1] },
        "compose_announcement" => { id: 1 },
        "create_journal_entry" => { body: "Wrote it down" },
        "create_post" => { title: "A draft" },
        "create_saved_view" => { name: "Open deploys", screen: "tasks" },
        "create_social_post" => { parts: ["Hello"], targets: ["mastodon"] },
        "delete_decision_comment" => { id: 1, comment_id: 2 },
        "delete_decision_option" => { id: 1, option_id: 2 },
        "delete_journal_entry" => { id: 1 },
        "delete_messages" => { ids: [1] },
        "delete_person" => { id: 1 },
        "delete_post" => { id: 1 },
        "delete_posts" => { ids: [1] },
        "delete_saved_view" => { id: 1 },
        "delete_social_post" => { id: 1 },
        "delete_task" => { id: 1 },
        "delete_task_comment" => { id: 1, comment_id: 2 },
        "delete_task_tag_rule" => { id: 1 },
        "delete_tasks" => { ids: [1] },
        "delete_work_entry" => { id: 1 },
        "delete_work_session" => { id: 1, session_id: 2 },
        "drop_decision" => { id: 1, reason: "Not needed" },
        "drop_sprint" => { id: 1 },
        "edit_decision" => { id: 1 },
        "edit_decision_comment" => { id: 1, comment_id: 2, body: "Leaning on Resque" },
        "edit_decision_option" => { id: 1, option_id: 2 },
        "edit_task_comment" => { id: 1, comment_id: 2, body: "Blocked on deploy" },
        "ignore_webmentions" => { ids: [1] },
        "import_commits" => {},
        "link_records" => { kind: "post", id: 1, other_kind: "commit", other_id: 2 },
        "link_tasks" => { id: 1, kind: "blocks", other_id: 2 },
        "list_api_tokens" => {},
        "list_attention" => {},
        "list_calendar" => { from: "2026-01-01", to: "2026-01-31" },
        "list_clients" => {},
        "list_commits" => { from: "2026-01-01", to: "2026-12-31" },
        "list_decisions" => {},
        "list_inbox" => {},
        "list_journal_entries" => { from: "2026-01-01", to: "2026-12-31" },
        "list_links" => { kind: "post", id: 1 },
        "list_messages" => { from: "2026-01-01", to: "2026-12-31" },
        "list_people" => {},
        "list_posts" => {},
        "list_projects" => {},
        "list_saved_views" => {},
        "list_social_posts" => { from: "2026-01-01", to: "2026-12-31" },
        "list_sprints" => {},
        "list_suggestions" => { from: "2026-01-01", to: "2026-12-31" },
        "list_tags" => { scope: "public" },
        "list_task_tag_rules" => {},
        "list_tasks" => {},
        "list_webmentions" => { from: "2026-01-01", to: "2026-12-31" },
        "list_work_entries" => { from: "2026-01-01", to: "2026-12-31" },
        "mark_message" => { id: 1, status: "read" },
        "mark_messages_read" => { ids: [1] },
        "mark_messages_unread" => { ids: [1] },
        "mark_task_seen" => { id: 1 },
        "mark_webmentions_spam" => { ids: [1] },
        "moderate_webmention" => { id: 1, verdict: "spam" },
        "move_task" => { id: 1, list: "next" },
        "move_tasks" => { ids: [1], list: "next" },
        "open_decision" => { title: "Pick a queue", problem: "Jobs pile up" },
        "pause_task" => { id: 1 },
        "plan_sprint" => { sprint_on: "2026-01-01" },
        "publish_post" => { id: 1 },
        "read_activity" => { from: "2026-01-01", to: "2026-12-31" },
        "read_analytics" => { from: "2026-01-01", to: "2026-12-31" },
        "read_commit" => { id: 1 },
        "read_current_sprint" => {},
        "read_decision" => { id: 1 },
        "read_journal_entry" => { id: 1 },
        "read_message" => { id: 1 },
        "read_person" => { id: 1 },
        "read_photo" => { photo: "x" },
        "read_post" => { id: 1 },
        "read_project" => { id: 1 },
        "read_review" => {},
        "read_saved_view" => { id: 1 },
        "read_social_post" => { id: 1 },
        "read_sync_state" => {},
        "read_tag" => { name: "ruby" },
        "read_task" => { id: 1 },
        "read_time_report" => { from: "2026-01-01", to: "2026-12-31" },
        "read_webmention" => { id: 1 },
        "read_webmention_settings" => {},
        "read_work_entry" => { id: 1 },
        "reject_suggestion_edits" => { suggestion_id: 1 },
        "remove_tag" => { id: 1, scope: "public" },
        "reopen_decision" => { id: 1, reason: "Load grew" },
        "reopen_task" => { id: 1 },
        "reorder_task" => { id: 1, direction: "up" },
        "resolve_decision" => { id: 1, option_id: 2, reason: "It runs today" },
        "restore_project" => { id: 1 },
        "save_person" => { name: "Ada Lovelace", key: "ada" },
        "save_project" => { id: 1 },
        "save_review_note" => { day: "2026-09-16", body: "A good week" },
        "save_tag" => { id: 1, scope: "public" },
        "save_task" => { id: 1 },
        "save_task_tag_rule" => { pattern: "aaronmallen/*", tags: ["ruby"] },
        "schedule_task" => { id: 1, sprint_on: "" },
        "search" => { query: "zeppelin" },
        "search_accounts" => { network: "bluesky", query: "ada" },
        "send_social_post" => { id: 1 },
        "set_task_total" => { id: 1, hours: 2 },
        "snooze_attention" => { kind: "journal" },
        "start_task" => { id: 1 },
        "suggest_edits" => { target: "post", id: 1, edits: [{ original: "teh", replacement: "the", reason: "typo" }] },
        "summarize_activity" => { from: "2026-01-01", to: "2026-12-31" },
        "sync_issues" => {},
        "tag_decision" => { id: 1, tags: ["queues"] },
        "tag_posts" => { ids: [1], tag: "ruby" },
        "tag_tasks" => { ids: [1], tag: "ruby" },
        "unlink_records" => { kind: "post", id: 1, other_kind: "commit", other_id: 2 },
        "unlink_task" => { id: 1, other_id: 2 },
        "untag_decision" => { id: 1, tag: "queues" },
        "untag_tasks" => { ids: [1], tag: "ruby" },
        "update_journal_entry" => { id: 1 },
        "update_post" => { id: 1 },
        "update_post_edit_note" => { id: 1, edit_id: 2, note: "Fixed the numbers" },
        "update_saved_view" => { id: 1 },
        "update_social_post" => { id: 1 },
        "update_webmention_settings" => {},
        "update_work_session" => { id: 1, session_id: 2, started_at: "2026-01-01T09:00" },
        "upload_photo" => { data: "", filename: "photo.png" },
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
