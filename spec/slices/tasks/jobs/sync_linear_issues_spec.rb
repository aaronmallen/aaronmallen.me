# frozen_string_literal: true

RSpec.describe Tasks::Jobs::SyncLinearIssues do
  let(:repo) { Tasks::Slice["repos.task_repo"] }
  let(:sync_state_repo) { Record::Slice["repos.sync_state_repo"] }
  let(:url) { "https://linear.app/aaronmallen/issue/abc-1/sync-my-issues" }

  before do
    connect_linear(LinearGraphQL::KEY)
    stub_assigned
    stub_known
  end

  def comments(task = imported) = Tasks::Slice["queries.task_comments"].call(task.id)

  def discussed(*nodes, **) = issue(comments: { nodes: }, **)

  def failure(name = Record::Repos::SyncStateRepo::LINEAR_ISSUES) = sync_state_repo.failure(name)

  def imported = repo.by_id(sources.at("linear", "L_one").pluck(:task_id).first)

  def issue(**) = linear_issue("L_one", **)

  def sources = Tasks::Slice["relations.task_sources"]

  def status(task) = repo.by_id(task.id).status

  def stub_assigned(*nodes) = stub_linear(LinearGraphQL::ASSIGNED_QUERY, linear_assigned(*nodes))

  def stub_known(*nodes)
    stub_linear(LinearGraphQL::ISSUES_QUERY) do |request|
      ids = JSON.parse(request.body).dig("variables", "ids")
      linear_issues(*nodes.select { ids.include?(it[:id]) })
    end
  end

  def sync = described_class.new.perform

  def tracked(*traits, state: "open", checked_at: nil, **)
    task = create(:task, *traits, list: "external", title: "Sync my issues", note: "Keep them in step", **)
    create(:task_source, provider: "linear", remote_id: "L_one", url:, remote_state: state, checked_at:, task:)

    repo.by_id(task.id)
  end

  describe "a new issue assigned to me" do
    before { stub_assigned(issue(title: "Sync Linear", description: "Keep Linear in step")) }

    it "becomes a task on the external list with no tags", :aggregate_failures do
      sync

      expect(imported).to have_attributes(list: "external", note: "Keep Linear in step", sprint_id: nil,
                                          status: "open", title: "Sync Linear")
      expect(imported.tags).to be_empty
    end

    it "links the task to its issue" do
      sync

      expect(imported.source).to have_attributes(provider: "linear", remote_id: "L_one", url:)
    end

    it "makes one task when the job runs twice" do
      2.times { sync }

      expect(sources.where(remote_id: "L_one").count).to eq(1)
    end

    it "clears a failure the last run left" do
      sync_state_repo.record_failure(Record::Repos::SyncStateRepo::LINEAR_ISSUES, :rate_limited)
      sync

      expect(failure).to be_nil
    end

    it "is asked for among only the issues that are not completed or canceled" do
      sync

      expect(linear_request('{state: {type: {nin: ["completed", "canceled"]}}}')).to have_been_made
    end

    it "is asked for 25 a page, so the query stays under Linear's complexity limit" do
      sync

      expect(linear_request("first: 25")).to have_been_made
    end

    it "is asked for with the key as it is, with no scheme" do
      sync

      expect(linear_request(LinearGraphQL::ASSIGNED_QUERY, key: LinearGraphQL::KEY)).to have_been_made
    end
  end

  describe "more pages of issues than the cap" do
    before do
      pages = 0
      stub_linear(LinearGraphQL::ASSIGNED_QUERY) do
        pages += 1
        linear_assigned(linear_issue("L_#{pages}", key: "ABC-#{pages}"), more: true)
      end
    end

    it "reads ten pages and imports what they held", :aggregate_failures do
      sync

      expect(linear_request(LinearGraphQL::ASSIGNED_QUERY)).to have_been_made.times(10)
      expect(sources.where(provider: "linear").count).to eq(10)
    end
  end

  describe "a new issue already started" do
    before { stub_assigned(issue(state: "started")) }

    it "arrives in progress", :aggregate_failures do
      sync

      expect(imported).to have_attributes(list: nil, status: "in_progress")
      expect(imported.source.remote_state).to eq("started")
    end

    it "arrives unseen" do
      sync

      expect(imported.source.seen_at).to be_nil
    end

    it "stays one task in progress when the job runs twice", :aggregate_failures do
      2.times { sync }

      expect(sources.where(remote_id: "L_one").count).to eq(1)
      expect(imported.status).to eq("in_progress")
    end
  end

  describe "a new issue with labels" do
    before { create(:tag, :private, name: "bug-fix") }

    def labeled(*names) = issue(labels: { nodes: names.map { { name: it } } })

    it "imports with the private tags its labels name" do
      create(:tag, :private, name: "needs-review")
      stub_assigned(labeled("Bug Fix", "needs review", "BugFix"))
      sync

      expect(imported.tags.map(&:name)).to contain_exactly("bug-fix", "needs-review")
    end

    it "adds no tag and creates none for a label no private tag matches", :aggregate_failures do
      create(:tag, name: "area-api")
      stub_assigned(labeled("area/api", "Someday"))

      expect { sync }.not_to(change { Tags::Slice["relations.tags"].count })
      expect(imported.tags).to be_empty
    end

    it "keeps a tag I removed off on the next sync" do
      stub_assigned(labeled("Bug Fix"))
      sync
      repo.replace_tags(imported.id, [])
      sync

      expect(imported.tags).to be_empty
    end

    it "adds no tag for a label added after import" do
      stub_assigned(labeled)
      sync
      stub_assigned(labeled("Bug Fix"))
      sync

      expect(imported.tags).to be_empty
    end

    it "names a label in a group by its own name alone" do
      create(:tag, :private, name: "type-bug-fix")
      stub_assigned(issue(labels: { nodes: [{ name: "Bug Fix", parent: { name: "Type" } }] }))
      sync

      expect(imported.tags.map(&:name)).to eq(%w[bug-fix])
    end
  end

  describe "a new issue in a team with tag rules" do
    before do
      create(:tag, :private, name: "bug-fix")
      rule("acme/eng", "ruby, hanami")
      rule("acme/*", "projects, ruby")
      rule("acme/*", "github", provider: "github")
    end

    def acme(key = "ENG-12", workspace: "acme", **)
      issue(key:, url: "https://linear.app/#{workspace}/issue/#{key.downcase}/sync-my-issues", **)
    end

    def rule(pattern, tags, provider: "linear")
      Tasks::Slice["operations.save_task_tag_rule"].call({ pattern:, provider:, tags: })
    end

    it "imports with the tags of every Linear rule it matches beside its label tags" do
      stub_assigned(acme(labels: { nodes: [{ name: "Bug Fix" }] }))
      sync

      expect(imported.tags.map(&:name)).to contain_exactly("bug-fix", "hanami", "projects", "ruby")
    end

    it "takes only the workspace rule's tags when the issue comes from another team" do
      stub_assigned(acme("OPS-3"))
      sync

      expect(imported.tags.map(&:name)).to contain_exactly("projects", "ruby")
    end

    it "takes no rule tags when the issue comes from another workspace" do
      stub_assigned(acme(workspace: "octocat"))
      sync

      expect(imported.tags).to be_empty
    end

    it "takes no rule tags once imported" do
      tracked
      stub_assigned(acme)
      sync

      expect(imported.tags).to be_empty
    end
  end

  describe "issues in every workspace I hold a key for" do
    before do
      connect_linear(LinearGraphQL::KEY, "lin_api_two")
      stub_linear(LinearGraphQL::ASSIGNED_QUERY, linear_assigned(issue), key: LinearGraphQL::KEY)
      stub_linear(LinearGraphQL::ASSIGNED_QUERY, linear_assigned(linear_issue("L_two", key: "XYZ-2")),
                  key: "lin_api_two")
    end

    it "become one task each" do
      sync

      expect(sources.where(provider: "linear").pluck(:remote_id)).to contain_exactly("L_one", "L_two")
    end
  end

  describe "an issue edited on Linear" do
    it "takes the new title and description" do
      task = tracked
      stub_assigned(issue(title: "New", description: "New body"))
      sync

      expect(repo.by_id(task.id)).to have_attributes(note: "New body", title: "New")
    end
  end

  describe "an issue's comments" do
    let(:at) { Time.utc(2026, 9, 28, 12) }

    def copied(id, author:, at:)
      { author:, body: "Looks good", created_at: at, provider: "linear", remote_id: id,
        url: "https://linear.app/aaronmallen/issue/abc-1/sync-my-issues#comment-#{id}" }
    end

    def remote(comment) = comment.to_h.slice(:author, :body, :created_at, :provider, :remote_id, :url)

    def rows = Tasks::Slice["relations.task_comments"]

    def sync_twice(first, second)
      stub_assigned(first)
      sync
      stub_assigned(second)
      sync
    end

    it "arrive on its task with author, body, time and link" do
      stub_assigned(discussed(linear_comment("c1", at:), linear_comment("c2", author: "sam", at: at + 60)))
      sync

      expect(comments.map { remote(it) })
        .to eq([copied("c1", author: "aaron", at:), copied("c2", author: "sam", at: at + 60)])
    end

    it "arrive on a task already tracked" do
      task = tracked
      stub_assigned(discussed(linear_comment("c1")))
      sync

      expect(comments(task).map(&:remote_id)).to eq(%w[c1])
    end

    it "add no rows and change nothing when synced again unchanged", :aggregate_failures do
      stub_assigned(discussed(linear_comment("c1"), linear_comment("c2")))
      before = sync.then { comments.map(&:to_h) }
      sync

      expect(comments.map(&:to_h)).to eq(before)
      expect(rows.count).to eq(2)
    end

    it "take an edit made on Linear" do
      sync_twice(discussed(linear_comment("c1")), discussed(linear_comment("c1", body: "Edited")))

      expect(comments.map(&:body)).to eq(%w[Edited])
    end

    it "arrive with no author when no user wrote them" do
      stub_assigned(discussed(linear_comment("c1", author: nil)))
      sync

      expect(comments.map(&:author)).to eq([nil])
    end

    it "lose one deleted on Linear" do
      sync_twice(discussed(linear_comment("c1"), linear_comment("c2")), discussed(linear_comment("c2")))

      expect(comments.map(&:remote_id)).to eq(%w[c2])
    end

    it "reach a tracked issue Linear reports through the check by id" do
      task = tracked
      stub_known(discussed(linear_comment("c1"), state: "started"))
      sync

      expect(comments(task).map(&:remote_id)).to eq(%w[c1])
    end

    it "leave my own comments alone" do
      task = tracked
      mine = create(:task_comment, task_id: task.id)
      stub_assigned(discussed(linear_comment("c1")))
      sync

      expect(comments(task).map(&:id)).to include(mine.id)
    end

    it "reach a task its issue reopens" do
      task = tracked(:done, state: "completed")
      stub_assigned(discussed(linear_comment("c1")))
      sync

      expect(comments(task).map(&:remote_id)).to eq(%w[c1])
    end

    it "stop at a task its issue cancels" do
      task = tracked
      stub_known(discussed(linear_comment("c1"), state: "canceled"))
      sync

      expect(comments(task)).to be_empty
    end

    it "stop coming to a task I finished" do
      task = tracked(:done)
      stub_assigned(discussed(linear_comment("c1")))
      sync

      expect(comments(task)).to be_empty
    end
  end

  describe "an issue whose title is blank once cleaned" do
    it "imports with its key as the title" do
      stub_assigned(issue(title: "\u0000 \u0000"))
      sync

      expect(imported.title).to eq("ABC-1")
    end

    it "keeps that title while the issue's title stays blank" do
      stub_assigned(issue(title: "\u0000"))
      sync
      stub_assigned(issue(title: " \u0000 ", description: "New body"))
      sync

      expect(imported).to have_attributes(note: "New body", title: "ABC-1")
    end

    it "takes a real title once the issue has one" do
      stub_assigned(issue(title: "\u0000"))
      sync
      stub_assigned(issue(title: "Sync Linear"))
      sync

      expect(imported.title).to eq("Sync Linear")
    end
  end

  describe "an issue that moves between states" do
    it "puts its task in progress when it starts", :aggregate_failures do
      task = tracked
      stub_assigned(issue(state: "started"))
      sync

      expect(repo.by_id(task.id)).to have_attributes(list: nil, status: "in_progress")
      expect(repo.by_id(task.id).sprint_id).not_to be_nil
    end

    it "leaves an unseen task unseen as it moves into Today" do
      task = tracked
      stub_assigned(issue(state: "started"))
      sync

      expect(repo.by_id(task.id).source.seen_at).to be_nil
    end

    %w[triage backlog unstarted].each do |type|
      it "reopens its task when it moves back to #{type}" do
        task = tracked(:in_progress, state: "started")
        stub_assigned(issue(state: type))
        sync

        expect(status(task)).to eq("open")
      end
    end

    it "marks its task done when it completes" do
      task = tracked
      stub_known(issue(state: "completed"))
      sync

      expect(status(task)).to eq("done")
    end

    it "cancels its task when it is canceled" do
      task = tracked
      stub_known(issue(state: "canceled"))
      sync

      expect(status(task)).to eq("canceled")
    end
  end

  describe "an issue reopened while I work on its closed task" do
    it "leaves the task in progress" do
      task = tracked(:in_progress, state: "completed")
      stub_assigned(issue)
      sync

      expect(status(task)).to eq("in_progress")
    end
  end

  describe "a started issue whose task I moved to a list" do
    it "leaves the task open while the issue stays started" do
      task = tracked(:in_progress, state: "started")
      Tasks::Slice["operations.move_task"].call(task.id, "external")
      stub_assigned(issue(state: "started"))
      sync

      expect(repo.by_id(task.id)).to have_attributes(list: "external", status: "open")
    end
  end

  describe "a synced issue's work session" do
    def sessions(task) = Tasks::Slice["relations.work_sessions"].for_task(task.id).to_a

    def started(task) = create(:work_session, task_id: task.id, started_at: Time.now - 3600)

    it "opens when the issue starts, at the time of the sync" do
      task = tracked
      stub_assigned(issue(state: "started"))
      sync

      expect(sessions(task)).to match([include(started_at: be_within(5).of(Time.now), ended_at: nil)])
    end

    it "opens when a new issue arrives already started" do
      stub_assigned(issue(state: "started"))
      sync

      expect(sessions(imported)).to match([include(started_at: be_within(5).of(Time.now), ended_at: nil)])
    end

    it "ends when the issue completes" do
      task = tracked(:in_progress, state: "started")
      started(task)
      stub_known(issue(state: "completed"))
      sync

      expect(sessions(task)).to match([include(ended_at: be_within(5).of(Time.now))])
    end

    it "adds its length to the total when the issue completes" do
      task = tracked(:in_progress, state: "started")
      started(task)
      stub_known(issue(state: "completed"))
      sync

      expect(repo.by_id(task.id).worked_seconds).to be_within(5).of(3600)
    end

    it "ends when the issue is canceled" do
      task = tracked(:in_progress, state: "started")
      started(task)
      stub_known(issue(state: "canceled"))
      sync

      expect(sessions(task)).to match([include(ended_at: be_within(5).of(Time.now))])
    end

    it "ends when the issue goes back to open" do
      task = tracked(:in_progress, state: "started")
      started(task)
      stub_assigned(issue)
      sync

      expect(sessions(task)).to match([include(ended_at: be_within(5).of(Time.now))])
    end
  end

  describe "a synced issue's events" do
    def changed(from, to) = [[from, to, be_within(5).of(Time.now)]]

    def events(task) = Tasks::Slice["relations.task_events"].for_task(task.id)

    def statuses(task)
      found = events(task).where(kind: "status_changed").in_order

      found.to_a.map { [it[:from_status], it[:to_status], it[:occurred_at]] }
    end

    it "records a start at the time of the sync" do
      task = tracked
      stub_assigned(issue(state: "started"))
      sync

      expect(statuses(task)).to match(changed("open", "in_progress"))
    end

    it "records a pause when the issue goes back to open" do
      task = tracked(:in_progress, state: "started")
      stub_assigned(issue)
      sync

      expect(statuses(task)).to match(changed("in_progress", "open"))
    end

    it "records a complete" do
      task = tracked(:in_progress, state: "started")
      stub_known(issue(state: "completed"))
      sync

      expect(statuses(task)).to match(changed("in_progress", "done"))
    end

    it "records a cancel" do
      task = tracked
      stub_known(issue(state: "canceled"))
      sync

      expect(statuses(task)).to match(changed("open", "canceled"))
    end

    it "records a reopen" do
      task = tracked(:done, state: "completed")
      stub_assigned(issue)
      sync

      expect(statuses(task)).to match(changed("done", "open"))
    end

    it "records the tags a new issue arrives with" do
      create(:tag, :private, name: "bug-fix")
      stub_assigned(issue(labels: { nodes: [{ name: "Bug Fix" }] }))
      sync

      expect(events(imported).to_a.map { [it[:kind], it[:tag_name]] }).to eq([%w[tagged bug-fix]])
    end
  end

  describe "an issue taken off me" do
    it "cancels its task" do
      task = tracked
      stub_known(issue(assignee: "someone-else"))
      sync

      expect(status(task)).to eq("canceled")
    end

    it "reopens the task when the issue is assigned back to me" do
      task = tracked(:canceled, state: "unassigned")
      stub_assigned(issue)
      sync

      expect(status(task)).to eq("open")
    end
  end

  describe "a deleted issue" do
    it "cancels its task when Linear puts it in the trash" do
      task = tracked
      stub_known(issue(trashed: true))
      sync

      expect(status(task)).to eq("canceled")
    end

    it "cancels its task when Linear no longer knows it" do
      task = tracked
      sync

      expect(status(task)).to eq("canceled")
    end
  end

  describe "tracked issues in two workspaces" do
    before do
      connect_linear(LinearGraphQL::KEY, "lin_api_two")
      tracked
      task = create(:task, list: "external")
      create(:task_source, provider: "linear", remote_id: "L_two", url: "https://linear.app/other/issue/xyz-2", task:)
      stub_linear(LinearGraphQL::ISSUES_QUERY, linear_issues(issue), key: LinearGraphQL::KEY)
      stub_linear(LinearGraphQL::ISSUES_QUERY, linear_issues(linear_issue("L_two", key: "XYZ-2", state: "completed")),
                  key: "lin_api_two")
    end

    it "are each found in their own workspace" do
      sync

      expect(sources.order(:remote_id).pluck(:remote_state)).to eq(%w[open completed])
    end

    it "ask the second workspace only for what the first did not find" do
      sync

      expect(linear_request(LinearGraphQL::ISSUES_QUERY, key: "lin_api_two", ids: %w[L_two])).to have_been_made
    end
  end

  describe "a tracked task deleted while the run waits on Linear" do
    before do
      task = tracked
      stub_linear(LinearGraphQL::ASSIGNED_QUERY) do
        Tasks::Slice["operations.delete_task"].call(task.id)
        linear_assigned(issue(title: "Renamed"), linear_issue("L_two", key: "ABC-2"))
      end
    end

    def other = repo.by_id(sources.at("linear", "L_two").pluck(:task_id).first)

    it "lets the rest of the run import" do
      sync

      expect(other.status).to eq("open")
    end

    it "lets the run clear a failure the last run left" do
      sync_state_repo.record_failure(Record::Repos::SyncStateRepo::LINEAR_ISSUES, :rate_limited)
      sync

      expect(failure).to be_nil
    end
  end

  describe "a deleted issue assigned to me again" do
    it "reopens its task instead of importing another" do
      task = tracked(:canceled, state: "deleted")
      stub_assigned(issue)
      sync

      expect(imported).to have_attributes(id: task.id, status: "open")
    end
  end

  describe "an issue checked an hour ago" do
    %w[completed not_planned unassigned].each do |state|
      it "is not asked about while #{state}" do
        tracked(:canceled, state:, checked_at: Time.now - 3600)
        sync

        expect(linear_request(LinearGraphQL::ISSUES_QUERY)).not_to have_been_made
      end
    end

    it "is asked about again while started" do
      tracked(:in_progress, state: "started", checked_at: Time.now - 3600)
      sync

      expect(linear_request(LinearGraphQL::ISSUES_QUERY, ids: %w[L_one])).to have_been_made
    end
  end

  describe "another provider's issue" do
    it "is not asked about" do
      create(:task_source, provider: "github", remote_id: "I_seven")
      sync

      expect(linear_request(LinearGraphQL::ISSUES_QUERY)).not_to have_been_made
    end
  end

  describe "more than 25 tracked issues" do
    before do
      26.times { create(:task_source, provider: "linear", task: create(:task, list: "external")) }
      stub_linear(LinearGraphQL::ISSUES_QUERY) do |request|
        linear_issues(*JSON.parse(request.body).dig("variables", "ids").map { linear_issue(it) })
      end
    end

    it "are checked 25 at a time" do
      sync

      expect(linear_request(LinearGraphQL::ISSUES_QUERY)).to have_been_made.twice
    end
  end

  describe "a run with nothing tracked" do
    it "checks nothing" do
      sync

      expect(linear_request(LinearGraphQL::ISSUES_QUERY)).not_to have_been_made
    end
  end

  describe "an archived issue" do
    it "leaves its task as it was" do
      task = tracked(:done, state: "completed")
      stub_known(issue(state: "completed", archivedAt: "2026-09-20T12:00:00.000Z"))
      sync

      expect(repo.by_id(task.id)).to have_attributes(completed_at: task.completed_at, status: "done")
    end

    it "is asked about among the archived" do
      tracked
      sync

      expect(linear_request("includeArchived: true")).to have_been_made
    end
  end

  describe "an issue moved to another team" do
    it "keeps the same task and follows the new link", :aggregate_failures do
      task = tracked
      stub_assigned(issue(key: "XYZ-9"))
      sync

      expect(repo.by_id(task.id).source.url).to eq("https://linear.app/aaronmallen/issue/xyz-9/sync-my-issues")
      expect(sources.count).to eq(1)
    end
  end

  describe "a status I set by hand" do
    it "holds while the issue stays in its state" do
      task = tracked(:done)
      stub_assigned(issue)
      sync

      expect(status(task)).to eq("done")
    end

    it "holds while the issue stays started" do
      task = tracked(:done, state: "started")
      stub_assigned(issue(state: "started"))
      sync

      expect(status(task)).to eq("done")
    end

    it "gives way when the issue goes back to open" do
      task = tracked(:done, state: "started")
      stub_assigned(issue)
      sync

      expect(status(task)).to eq("open")
    end

    it "gives way when the issue's state changes" do
      task = tracked(:done)
      stub_assigned(issue(state: "started"))
      sync

      expect(status(task)).to eq("in_progress")
    end
  end

  describe "a failed run" do
    it "records Linear's refusal under linear_issues", :aggregate_failures do
      stub_linear(LinearGraphQL::ASSIGNED_QUERY, linear_errors("RATELIMITED"))
      sync

      expect(failure).to include(reason: "rate_limited")
      expect(failure(Record::Repos::SyncStateRepo::ISSUES)).to be_nil
    end

    it "records a check Linear fails rather than cancel the task", :aggregate_failures do
      task = tracked
      stub_linear(LinearGraphQL::ISSUES_QUERY, { status: 500 })
      sync

      expect(failure).to include(reason: "linear_failed")
      expect(status(task)).to eq("open")
    end

    it "records a 429 as rate limited" do
      stub_linear(LinearGraphQL::ASSIGNED_QUERY, { status: 429 })
      sync

      expect(failure).to include(reason: "rate_limited")
    end

    it "records the error Linear names" do
      stub_linear(LinearGraphQL::ASSIGNED_QUERY, linear_errors("AUTHENTICATION_ERROR", "Authentication required"))
      sync

      expect(failure).to include(reason: "linear_failed", message: /Authentication required/)
    end

    it "records a connection that fails" do
      stub_request(:post, LinearGraphQL::URL).to_timeout
      sync

      expect(failure).to include(reason: "linear_failed", message: /failed/)
    end

    it "records a check Linear answers with no viewer rather than cancel the task", :aggregate_failures do
      task = tracked
      stub_linear(LinearGraphQL::ISSUES_QUERY, linear_json(data: { issues: { nodes: [issue] } }))
      sync

      expect(failure).to include(reason: "linear_failed", message: /no viewer/)
      expect(status(task)).to eq("open")
    end
  end

  describe "a failure in one provider" do
    before do
      connect_github_token
      stub_github(GitHubGraphQL::ASSIGNED_QUERY, github_issue_search(github_issue("I_seven", number: 7)))
      stub_linear(LinearGraphQL::ASSIGNED_QUERY, linear_assigned(issue))
    end

    def both
      sync
      Tasks::Jobs::SyncIssues.new.perform
    end

    it "leaves GitHub to run when Linear fails", :aggregate_failures do
      stub_linear(LinearGraphQL::ASSIGNED_QUERY, { status: 500 })
      both

      expect(failure).to include(reason: "linear_failed")
      expect(sources.at("github", "I_seven").count).to eq(1)
    end

    it "leaves Linear to run when GitHub fails", :aggregate_failures do
      stub_github(GitHubGraphQL::ASSIGNED_QUERY, { status: 500 })
      both

      expect(failure(Record::Repos::SyncStateRepo::ISSUES)).to include(reason: "github_failed")
      expect([failure, imported]).to match([nil, be_truthy])
    end
  end

  describe "with no Linear keys" do
    before { connect_linear }

    it "asks Linear for nothing and records nothing", :aggregate_failures do
      sync

      expect(a_request(:any, LinearGraphQL::URL)).not_to have_been_made
      expect(failure).to be_nil
    end
  end

  describe "when another run is already going" do
    let(:connection) { Tasks::Slice["db.rom"].gateways.fetch(:default).connection }
    let(:elsewhere) { Sequel.connect(connection.opts) }

    before do
      lock = Tasks::Repos::TaskSourceRepo::SYNC_LOCKS.fetch("linear")
      elsewhere.get(Sequel.function(:pg_try_advisory_lock, lock))
    end

    after { elsewhere.disconnect }

    it "leaves the run to the one holding the lock", :aggregate_failures do
      sync

      expect(linear_request(LinearGraphQL::ASSIGNED_QUERY)).not_to have_been_made
      expect(failure).to be_nil
    end

    it "leaves the GitHub run free" do
      connect_github_token
      stub_github(GitHubGraphQL::ASSIGNED_QUERY, github_issue_search)
      Tasks::Jobs::SyncIssues.new.perform

      expect(github_request(GitHubGraphQL::ASSIGNED_QUERY)).to have_been_made
    end
  end
end
