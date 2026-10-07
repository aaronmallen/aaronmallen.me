# frozen_string_literal: true

RSpec.describe Tasks::Jobs::SyncIssues do
  let(:repo) { Tasks::Slice["repos.task_repo"] }
  let(:url) { "https://github.com/aaronmallen/aaronmallen.me/issues/7" }

  def api = "https://api.github.com"
  def comments(task = imported) = Tasks::Slice["queries.task_comments"].call(task.id)

  before do
    connect_github_token
    stub_assigned
    stub_known
  end

  def discussed(*nodes, **) = issue(comments: { nodes: }, **)

  def failure = sync_state_queries.failure(Blog::Types::SyncName["issues"])

  def imported(id = "I_seven") = repo.by_id(sources.at("github", id).pluck(:task_id).first)

  def issue(id = "I_seven", **) = github_issue(id, number: 7, **)

  def sources = Tasks::Slice["relations.task_sources"]

  def stub_assigned(*nodes) = stub_github(GitHubGraphQL::ASSIGNED_QUERY, github_issue_search(*nodes))

  def stub_known(*nodes)
    stub_github(GitHubGraphQL::ISSUES_QUERY) do |request|
      ids = JSON.parse(request.body).dig("variables", "ids")
      github_issue_nodes(*ids.map { |id| nodes.find { it[:id] == id } })
    end
  end

  def stub_rest(path, response) = stub_request(:get, "#{api}/repos/#{path}").to_return(response)

  def stub_vanished(response)
    stub_github(GitHubGraphQL::ISSUES_QUERY, github_missing_issue)
    stub_rest("aaronmallen/aaronmallen.me/issues/7", response)
  end

  def sync = described_class.new.perform

  def sync_state_mutations = Record::Slice["repos.sync_state_mutations"]

  def sync_state_queries = Record::Slice["repos.sync_state_queries"]

  def tracked(*traits, state: "open", checked_at: nil, **)
    task = create(:task, *traits, list: "external", **)

    create(:task_source, remote_id: "I_seven", url:, remote_state: state, checked_at:, task:)
      .then { repo.by_id(it.task_id) }
  end

  describe "a new issue assigned to me" do
    before { stub_assigned(issue(title: "Sync my issues", body: "Keep them in step")) }

    it "becomes a task on the external list with no tags", :aggregate_failures do
      sync

      expect(imported).to have_attributes(list: "external", note: "Keep them in step", sprint_id: nil,
                                          status: "open", title: "Sync my issues")
      expect(imported.tags).to be_empty
    end

    it "links the task to its issue" do
      sync

      expect(imported.source).to have_attributes(provider: "github", remote_id: "I_seven", url:)
    end

    it "arrives unseen" do
      sync

      expect(imported.source.seen_at).to be_nil
    end

    it "makes one task when the job runs twice" do
      2.times { sync }

      expect(Tasks::Slice["relations.task_sources"].where(remote_id: "I_seven").count).to eq(1)
    end

    it "clears a failure the last run left" do
      sync_state_mutations.record_failure(Blog::Types::SyncName["issues"], :rate_limited)
      sync

      expect(failure).to be_nil
    end

    it "is found by a search of every repository for open issues, not pull requests, assigned to me" do
      sync

      expect(github_request("is:issue is:open assignee:@me")).to have_been_made
    end
  end

  describe "a search result that is not an issue" do
    it "is skipped while the rest import" do
      stub_assigned({}, issue)
      sync

      expect(sources.pluck(:remote_id)).to eq(%w[I_seven])
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

    it "arrives unseen with its tags" do
      stub_assigned(labeled("Bug Fix"))
      sync

      expect(imported.source.seen_at).to be_nil
    end

    it "adds no tag and creates none for a label no private tag matches", :aggregate_failures do
      create(:tag, name: "area-api")
      stub_assigned(labeled("area/api", "Someday"))

      expect { sync }.not_to(change { Tags::Slice["relations.tags"].count })
      expect(imported.tags).to be_empty
    end

    it "keeps the app's acronyms whole in a label" do
      create(:tag, :private, name: "github")
      stub_assigned(labeled("GitHub"))
      sync

      expect(imported.tags.map(&:name)).to eq(%w[github])
    end

    it "imports with no tag for a label with no valid form", :aggregate_failures do
      stub_assigned(labeled("!!!", ""))
      sync

      expect(imported.status).to eq("open")
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
  end

  describe "a new issue from a repo with task rules" do
    before do
      create(:tag, :private, name: "bug-fix")
      rule("aaronmallen/aaronmallen.me", "ruby, hanami")
      rule("aaronmallen/*", "projects, ruby")
    end

    def events = Tasks::Slice["relations.task_events"].for_task(imported.id).to_a

    def rule(pattern, tags, **) = Tasks::Slice["operations.save_task_rule"].call({ pattern:, tags:, ** })

    it "imports with the tags of every rule it matches beside its label tags" do
      stub_assigned(issue(labels: { nodes: [{ name: "Bug Fix" }] }))
      sync

      expect(imported.tags.map(&:name)).to contain_exactly("bug-fix", "hanami", "projects", "ruby")
    end

    it "records each tag once in the import's task event" do
      stub_assigned(issue(labels: { nodes: [{ name: "Ruby" }] }))
      sync

      expect(events.map { [it[:kind], it[:tag_name]] })
        .to contain_exactly(%w[tagged hanami], %w[tagged projects], %w[tagged ruby])
    end

    it "matches the repo whatever its case" do
      stub_assigned(issue(repo: "AaronMallen/AaronMallen.me"))
      sync

      expect(imported.tags.map(&:name)).to contain_exactly("hanami", "projects", "ruby")
    end

    it "takes no tags from a Linear rule for its owner" do
      rule("aaronmallen/*", "linear", provider: "linear")
      stub_assigned(issue)
      sync

      expect(imported.tags.map(&:name)).to contain_exactly("hanami", "projects", "ruby")
    end

    it "takes no rule tags when the issue comes from another owner" do
      stub_assigned(issue(repo: "octocat/aaronmallen.me"))
      sync

      expect(imported.tags).to be_empty
    end

    it "keeps a tag I removed off on the next sync" do
      stub_assigned(issue)
      sync
      repo.replace_tags(imported.id, %w[ruby])
      sync

      expect(imported.tags.map(&:name)).to eq(%w[ruby])
    end
  end

  describe "a new issue from a repo with rules that hold projects" do
    let(:blog) { create(:project, :private) }
    let(:site) { create(:project, :archived) }

    before do
      rule("aaronmallen/aaronmallen.me", projects: [blog.id, site.id])
      rule("aaronmallen/*", tags: "ruby", projects: [blog.id])
    end

    def links = Links::Slice["repos.record_link_repo"]

    def project_ids = links.partners("task", imported.id).filter_map { |kind, id| id if kind == "project" }

    def rule(pattern, tags: "", projects: [])
      Tasks::Slice["operations.save_task_rule"].call({ pattern:, tags:, projects: }).value!
    end

    it "links to the projects of every rule it matches, private or archived, once each" do
      stub_assigned(issue)
      sync

      expect(project_ids).to contain_exactly(blog.id, site.id)
    end

    it "links once to a project its repo and a rule both name" do
      Projects::Slice["repos.project_repo"].update(blog.id, repo: "aaronmallen/aaronmallen.me")
      stub_assigned(issue)
      sync

      expect(project_ids).to contain_exactly(blog.id, site.id)
    end

    describe "and a project that owns its repo" do
      before { create(:project, repo: "aaronmallen/aaronmallen.me") }

      def owner_id = Projects::Slice["relations.projects"].where(repo: "aaronmallen/aaronmallen.me").pluck(:id).first

      it "links to that project beside the rule projects" do
        stub_assigned(issue(repo: "AaronMallen/AaronMallen.me"))
        sync

        expect(project_ids).to contain_exactly(blog.id, site.id, owner_id)
      end

      it "keeps a link to that project I removed off on the next sync" do
        stub_assigned(issue)
        sync
        links.unlink(["task", imported.id], ["project", owner_id])
        sync

        expect(project_ids).to contain_exactly(blog.id, site.id)
      end
    end

    it "links to no project when the issue comes from another owner" do
      stub_assigned(issue(repo: "octocat/aaronmallen.me"))
      sync

      expect(project_ids).to be_empty
    end

    it "keeps a project link I removed off on the next sync" do
      stub_assigned(issue)
      sync
      links.unlink(["task", imported.id], ["project", site.id])
      sync

      expect(project_ids).to eq([blog.id])
    end
  end

  describe "an issue edited on GitHub" do
    it "takes the new title and body" do
      task = tracked(title: "Old", note: "Old body")
      stub_assigned(issue(title: "New", body: "New body"))
      sync

      expect(repo.by_id(task.id)).to have_attributes(note: "New body", title: "New")
    end

    it "leaves an unchanged task untouched" do
      task = tracked(title: "Sync my issues", note: "Keep them in step", updated_at: Time.now - 3600)
      stub_assigned(issue)
      sync

      expect(repo.by_id(task.id).updated_at).to be_within(1).of(task.updated_at)
    end

    it "follows the issue to its new URL" do
      task = tracked
      stub_assigned(issue(repo: "aaronmallen/renamed"))
      sync

      expect(repo.by_id(task.id).source.url).to eq("https://github.com/aaronmallen/renamed/issues/7")
    end
  end

  describe "an issue with a NUL byte in its title or body" do
    it "imports as a task without the byte" do
      stub_assigned(issue(title: "Sync\u0000 my issues", body: "Keep\u0000 them in step"))
      sync

      expect(imported).to have_attributes(note: "Keep them in step", title: "Sync my issues")
    end

    it "takes a later change as usual" do
      stub_assigned(issue(title: "Sync\u0000 my issues", body: "Keep\u0000 them in step"))
      sync
      stub_assigned(issue(title: "Sync\u0000 every issue", body: "Keep\u0000 them all in step"))
      sync

      expect(imported).to have_attributes(note: "Keep them all in step", title: "Sync every issue")
    end

    it "leaves the task untouched while the issue stays the same" do
      task = tracked(title: "Sync my issues", note: "Keep them in step", updated_at: Time.now - 3600)
      stub_assigned(issue(title: "Sync\u0000 my issues", body: "Keep\u0000 them in step"))
      sync

      expect(repo.by_id(task.id).updated_at).to be_within(1).of(task.updated_at)
    end
  end

  describe "an issue whose title is blank once cleaned" do
    let(:reference) { "aaronmallen/aaronmallen.me#7" }

    it "imports with its reference as the title" do
      stub_assigned(issue(title: "\u0000 \u0000"))
      sync

      expect(imported.title).to eq(reference)
    end

    it "keeps that title while the issue's title stays blank" do
      stub_assigned(issue(title: "\u0000"))
      sync
      stub_assigned(issue(title: " \u0000 ", body: "New body"))
      sync

      expect(imported).to have_attributes(note: "New body", title: reference)
    end

    it "takes a real title once the issue has one" do
      stub_assigned(issue(title: "\u0000"))
      sync
      stub_assigned(issue(title: "Sync my issues"))
      sync

      expect(imported.title).to eq("Sync my issues")
    end
  end

  describe "an issue's comments" do
    let(:at) { Time.utc(2026, 9, 28, 12) }

    def copied(id, author:, at:)
      { author:, body: "Looks good", created_at: at, provider: "github", remote_id: id,
        url: "https://github.com/aaronmallen/aaronmallen.me/issues/7#issuecomment-#{id.delete_prefix('IC_')}" }
    end

    def remote(comment) = comment.to_h.slice(:author, :body, :created_at, :provider, :remote_id, :url)

    def sync_twice(first, second)
      stub_assigned(first)
      sync
      stub_assigned(second)
      sync
    end

    it "arrive on its task with author, body, time and link" do
      stub_assigned(discussed(github_comment("IC_1", at:), github_comment("IC_2", author: "hubot", at: at + 60)))
      sync

      expect(comments.map { remote(it) })
        .to eq([copied("IC_1", author: "octocat", at:), copied("IC_2", author: "hubot", at: at + 60)])
    end

    it "arrive with no author from a deleted account" do
      stub_assigned(discussed(github_comment("IC_1", author: nil)))
      sync

      expect(comments.map(&:author)).to eq([nil])
    end

    it "arrive on a task already tracked" do
      task = tracked
      stub_assigned(discussed(github_comment("IC_1")))
      sync

      expect(comments(task).map(&:remote_id)).to eq(%w[IC_1])
    end

    it "add no rows and change nothing when synced again unchanged", :aggregate_failures do
      stub_assigned(discussed(github_comment("IC_1"), github_comment("IC_2")))
      before = sync.then { comments.map(&:to_h) }
      sync

      expect(comments.map(&:to_h)).to eq(before)
      expect(Tasks::Slice["relations.task_comments"].count).to eq(2)
    end

    it "take an edit made on GitHub" do
      sync_twice(discussed(github_comment("IC_1")), discussed(github_comment("IC_1", body: "Edited")))

      expect(comments.map(&:body)).to eq(%w[Edited])
    end

    it "lose one deleted on GitHub" do
      sync_twice(discussed(github_comment("IC_1"), github_comment("IC_2")), discussed(github_comment("IC_2")))

      expect(comments.map(&:remote_id)).to eq(%w[IC_2])
    end

    it "leave my own comments alone" do
      task = tracked
      mine = create(:task_comment, task_id: task.id)
      stub_assigned(discussed(github_comment("IC_1")))
      sync

      expect(comments(task).map(&:id)).to include(mine.id)
    end

    it "skip a comment with nothing to show once cleaned" do
      stub_assigned(discussed(github_comment("IC_1", body: "\u0000 "), github_comment("IC_2", body: "Fine\u0000")))
      sync

      expect(comments.map { [it.remote_id, it.body] }).to eq([%w[IC_2 Fine]])
    end

    it "stop coming to a task I finished" do
      task = tracked(:done)
      stub_assigned(discussed(github_comment("IC_1")))
      sync

      expect(comments(task)).to be_empty
    end

    it "stop coming to a canceled task" do
      task = tracked(:canceled, state: "not_planned")
      stub_known(discussed(github_comment("IC_1"), state: "CLOSED", stateReason: "NOT_PLANNED"))
      sync

      expect(comments(task)).to be_empty
    end

    it "stop coming once the issue is taken off me and its task canceled" do
      task = tracked
      stub_known(discussed(github_comment("IC_1"), assignees: ["MDQ6VXNlcjE="]))
      sync

      expect(comments(task)).to be_empty
    end

    context "when GitHub rate limits the run part way" do
      before { stub_github(GitHubGraphQL::ISSUES_QUERY, github_rate_limited) }

      it "save nothing", :aggregate_failures do
        tracked
        stub_assigned(github_issue("I_eight", number: 8, comments: { nodes: [github_comment("IC_1")] }))
        sync

        expect(failure).to include(reason: "rate_limited")
        expect(Tasks::Slice["relations.task_comments"].count).to eq(0)
      end
    end
  end

  describe "an issue's relations" do
    let(:client) { Tasks::Slice["record.github.client"] }
    let(:found) { [] }

    def collect(issues) = issues.tap { found.concat(it) }

    def gather(name) = allow(client).to(receive(name).and_wrap_original { |read, *args| collect(read.call(*args)) })

    def handed_over(id = "I_seven")
      gather(:assigned_issues)
      gather(:issues)
      described_class.new(client:).perform
      found.find { it[:id] == id }
    end

    def lookup_with(*fields)
      a_request(:post, GitHubGraphQL::URL).with do |request|
        query = JSON.parse(request.body)["query"]
        query.include?(GitHubGraphQL::ISSUES_QUERY) && fields.all? { query.include?(it) }
      end
    end

    it "come with an assigned issue as kind and remote id from the issue's side" do
      stub_assigned(issue(blockedBy: github_related("I_one"), blocking: github_related("I_two", "I_three"),
                          parent: { id: "I_four" }, subIssues: github_related("I_five")))

      kinds = [%w[child_of I_four], %w[blocked_by I_one], %w[blocks I_two], %w[blocks I_three], %w[parent_of I_five]]

      expect(handed_over[:relations]).to eq(kinds.map { |kind, remote_id| { kind:, remote_id: } })
    end

    it "come with an issue looked up by id" do
      tracked
      stub_known(issue(blocking: github_related("I_two"), assignees: ["MDQ6VXNlcjE="]))

      expect(handed_over[:relations]).to eq([{ kind: "blocks", remote_id: "I_two" }])
    end

    it "come as an empty list for an issue with none" do
      stub_assigned(issue)

      expect(handed_over[:relations]).to eq([])
    end

    it "are asked for without tracked issues" do
      stub_assigned(issue)
      sync

      expect(a_request(:post, GitHubGraphQL::URL).with { it.body.include?("tracked") }).not_to have_been_made
    end

    it "are asked for in the lookup by id" do
      tracked
      stub_known(issue)
      sync

      expect(lookup_with("blockedBy", "blocking", "parent", "subIssues")).to have_been_made.once
    end

    it "are left out when one kind runs past a page" do
      stub_assigned(issue(blockedBy: github_related("I_one"), subIssues: github_related("I_five", more: true)))

      expect(handed_over).not_to have_key(:relations)
    end

    it "are left out when GitHub hides an issue at the other end" do
      stub_assigned(issue(blocking: github_related("I_two", nil)))

      expect(handed_over).not_to have_key(:relations)
    end

    it "are left out when GitHub sends no relations" do
      stub_assigned(issue.except(:blockedBy))

      expect(handed_over).not_to have_key(:relations)
    end

    it "leave a rate limited check reported as before", :aggregate_failures do
      task = tracked
      stub_github(GitHubGraphQL::ISSUES_QUERY, github_errors("RATE_LIMITED", data: { rateLimit: github_rate_limit }))
      sync

      expect(failure).to include(reason: "rate_limited")
      expect(repo.by_id(task.id).status).to eq("open")
    end
  end

  describe "an issue's links" do
    let(:other) { "MDQ6VXNlcjE=" }

    def drop_relation
      stub_assigned(issue)
      stub_known(node("I_one", 1, assignees: [other]))
    end

    def hold(id, *traits, state: "open")
      task = create(:task, *traits, list: "external")
      create(:task_source, remote_id: id, remote_state: state, task:)

      repo.by_id(task.id)
    end

    def links
      remote = sources.pluck(:task_id, :remote_id).to_h

      rows = Tasks::Slice["relations.task_links"].pluck(:from_task_id, :type, :to_task_id, :synced)

      rows.map { |from, type, to, synced| [remote[from], type, remote[to], synced] }
    end

    def node(id, number, **) = github_issue(id, number:, **)

    def pair(**) = [issue(blockedBy: github_related("I_one")), node("I_one", 1, **)]

    it "blocks a task its blocker blocks once both are in" do
      stub_assigned(*pair(blocking: github_related("I_seven")))
      sync

      expect(imported).to be_blocked
    end

    it "links two related issues imported in the same run" do
      stub_assigned(*pair(blocking: github_related("I_seven")))
      sync

      expect(links).to eq([["I_one", "blocks", "I_seven", true]])
    end

    it "links an issue imported in the run to a task already here" do
      hold("I_one")
      stub_known(node("I_one", 1, blocking: github_related("I_seven")))
      stub_assigned(issue(blockedBy: github_related("I_one")))
      sync

      expect(links).to eq([["I_one", "blocks", "I_seven", true]])
    end

    it "gives a sub-issue a parent link from its parent" do
      stub_assigned(issue(parent: { id: "I_one" }), node("I_one", 1, subIssues: github_related("I_seven")))
      sync

      expect(links).to eq([["I_one", "parent", "I_seven", true]])
    end

    it "keeps a parent link while the parent names the child, though GitHub hides the parent from the child" do
      stub_assigned(issue(parent: { id: "I_one" }), node("I_one", 1, subIssues: github_related("I_seven")))
      sync
      stub_assigned(issue, node("I_one", 1, subIssues: github_related("I_seven")))
      sync

      expect(links).to eq([["I_one", "parent", "I_seven", true]])
    end

    it "keeps the strongest kind when upstream gives one pair two" do
      stub_assigned(issue(parent: { id: "I_one" }, blockedBy: github_related("I_one")), node("I_one", 1))
      sync

      expect(links).to eq([["I_one", "parent", "I_seven", true]])
    end

    context "when the other end is not in the app" do
      before do
        stub_assigned(issue(blockedBy: github_related("I_one")))
        neighbor = node("I_one", 1, assignees: [other], blockedBy: github_related("I_two"))
        stub_known(neighbor, node("I_two", 2, assignees: [other]))
      end

      it "imports it and links it", :aggregate_failures do
        sync

        expect(imported("I_one")).to have_attributes(list: "external", status: "open")
        expect(links).to eq([["I_one", "blocks", "I_seven", true]])
      end

      it "does not pull in the imported issue's own relations" do
        2.times { sync }

        expect(sources.pluck(:remote_id)).to contain_exactly("I_seven", "I_one")
      end

      it "keeps the imported task open while a synced link holds it" do
        2.times { sync }

        expect(imported("I_one").status).to eq("open")
      end

      it "drops the link once the relation goes upstream" do
        sync
        drop_relation
        sync

        expect(links).to be_empty
      end

      it "keeps the imported task open on the run that drops its last synced link" do
        sync
        drop_relation
        sync

        expect(imported("I_one").status).to eq("open")
      end

      it "cancels the imported task on the run after its last synced link goes" do
        sync
        drop_relation
        2.times { sync }

        expect(imported("I_one").status).to eq("canceled")
      end
    end

    it "does not import a closed issue at the other end" do
      stub_assigned(issue(blockedBy: github_related("I_one")))
      stub_known(node("I_one", 1, assignees: [other], state: "CLOSED", stateReason: "COMPLETED"))
      sync

      expect(sources.pluck(:remote_id)).to eq(%w[I_seven])
    end

    it "does not import an issue GitHub cannot find" do
      stub_assigned(issue(blockedBy: github_related("I_one")))
      sync

      expect(sources.pluck(:remote_id)).to eq(%w[I_seven])
    end

    it "reports a failed lookup of the other end and still links the rest", :aggregate_failures do
      stub_assigned(issue(blockedBy: github_related("I_one", "I_two")), node("I_one", 1))
      stub_github(GitHubGraphQL::ISSUES_QUERY, github_errors("RATE_LIMITED", data: { rateLimit: github_rate_limit }))
      sync

      expect(failure).to include(reason: "rate_limited")
      expect(links).to eq([["I_one", "blocks", "I_seven", true]])
    end

    it "removes a synced link once the relation goes upstream" do
      stub_assigned(*pair(blocking: github_related("I_seven")))
      sync
      stub_assigned(issue, node("I_one", 1))
      sync

      expect(links).to be_empty
    end

    it "changes a synced link whose kind changes upstream" do
      stub_assigned(*pair)
      sync
      stub_assigned(issue(parent: { id: "I_one" }), node("I_one", 1))
      sync

      expect(links).to eq([["I_one", "parent", "I_seven", true]])
    end

    it "leaves a synced link alone while GitHub leaves the relations out" do
      stub_assigned(*pair)
      sync
      stub_assigned(issue.except(:blockedBy), node("I_one", 1).except(:blocking))
      sync

      expect(links).to eq([["I_one", "blocks", "I_seven", true]])
    end

    context "with a link I made by hand" do
      before { create(:task_link, :relates, from_task_id: tracked.id, to_task_id: hold("I_one").id) }

      it "keeps it and adds no synced link on its pair" do
        stub_assigned(*pair)
        sync

        expect(links).to eq([["I_seven", "relates", "I_one", false]])
      end

      it "keeps it when upstream names no relation" do
        stub_assigned(issue, node("I_one", 1))
        sync

        expect(links).to eq([["I_seven", "relates", "I_one", false]])
      end
    end

    it "adds no parent to a task that has one by hand" do
      create(:task_link, :parent, from_task_id: create(:task).id, to_task_id: tracked.id)
      stub_assigned(issue(parent: { id: "I_one" }), node("I_one", 1))
      sync

      expect(links.select(&:last)).to be_empty
    end

    context "with a closed task" do
      before do
        blocker = hold("I_one", :done, state: "completed")
        create(:task_link, from_task_id: blocker.id, to_task_id: tracked.id, synced: true)
      end

      it "keeps its synced link when upstream drops the relation" do
        stub_assigned(issue)
        sync

        expect(links).to eq([["I_one", "blocks", "I_seven", true]])
      end

      it "does not refresh its links from upstream" do
        stub_assigned(issue)
        stub_known(node("I_one", 1, state: "CLOSED", stateReason: "COMPLETED", subIssues: github_related("I_seven")))
        sync

        expect(links).to eq([["I_one", "blocks", "I_seven", true]])
      end
    end
  end

  describe "an issue closed on GitHub" do
    it "marks the task done when it closed as completed" do
      task = tracked
      stub_known(issue(state: "CLOSED", stateReason: "COMPLETED"))
      sync

      expect(repo.by_id(task.id).status).to eq("done")
    end

    it "cancels the task when it closed as not planned" do
      task = tracked
      stub_known(issue(state: "CLOSED", stateReason: "NOT_PLANNED"))
      sync

      expect(repo.by_id(task.id).status).to eq("canceled")
    end

    it "cancels the task when it closed as a duplicate" do
      task = tracked
      stub_known(issue(state: "CLOSED", stateReason: "DUPLICATE"))
      sync

      expect(repo.by_id(task.id).status).to eq("canceled")
    end

    it "marks the task done when it closed with no reason" do
      task = tracked
      stub_known(issue(state: "CLOSED", stateReason: nil))
      sync

      expect(repo.by_id(task.id).status).to eq("done")
    end

    it "moves the task to done when a not planned issue is closed again as completed" do
      task = tracked(:canceled, state: "not_planned")
      stub_known(issue(state: "CLOSED", stateReason: "COMPLETED"))
      sync

      expect(repo.by_id(task.id).status).to eq("done")
    end
  end

  describe "an issue reopened on GitHub" do
    it "reopens its done task" do
      task = tracked(:done, state: "completed")
      stub_assigned(issue)
      sync

      expect(repo.by_id(task.id)).to have_attributes(completed_at: nil, status: "open")
    end

    it "reopens its canceled task" do
      task = tracked(:canceled, state: "not_planned")
      stub_assigned(issue)
      sync

      expect(repo.by_id(task.id).status).to eq("open")
    end
  end

  describe "a closed issue" do
    let(:day) { 24 * 60 * 60 }

    def checks = github_request(GitHubGraphQL::ISSUES_QUERY)

    it "is checked once, then left alone for a day" do
      tracked(:done, state: "completed")
      stub_known(issue(state: "CLOSED", stateReason: "COMPLETED"))
      2.times { sync }

      expect(checks).to have_been_made.once
    end

    it "is checked again once a day has passed", :aggregate_failures do
      task = tracked(:done, state: "completed", checked_at: Time.now - day - 60)
      stub_known(issue(state: "CLOSED", stateReason: "COMPLETED"))
      sync

      expect(checks).to have_been_made.once
      expect(repo.by_id(task.id).source.checked_at).to be_within(5).of(Time.now)
    end

    it "moves its task back when reopened upstream" do
      task = tracked(:done, state: "completed", checked_at: Time.now - day)
      stub_known(issue)
      sync

      expect(repo.by_id(task.id).status).to eq("open")
    end

    it "is checked every run while open" do
      tracked
      stub_known(issue)
      2.times { sync }

      expect(checks).to have_been_made.twice
    end
  end

  describe "more than a hundred tracked issues" do
    before do
      101.times { create(:task_source, task: create(:task, list: "external")) }
      stub_github(GitHubGraphQL::ISSUES_QUERY) do |request|
        github_issue_nodes(*JSON.parse(request.body).dig("variables", "ids").map { github_issue(it) })
      end
    end

    it "are checked a hundred at a time" do
      sync

      expect(github_request(GitHubGraphQL::ISSUES_QUERY)).to have_been_made.twice
    end
  end

  describe "an issue taken off me" do
    it "cancels its task" do
      task = tracked
      stub_known(issue(assignees: ["MDQ6VXNlcjE="]))
      sync

      expect(repo.by_id(task.id).status).to eq("canceled")
    end

    it "marks the task done when the issue was also closed as completed" do
      task = tracked
      stub_known(issue(assignees: ["MDQ6VXNlcjE="], state: "CLOSED", stateReason: "COMPLETED"))
      sync

      expect(repo.by_id(task.id).status).to eq("done")
    end

    it "leaves a task I finished done" do
      task = tracked(:done)
      stub_known(issue(assignees: ["MDQ6VXNlcjE="]))
      sync

      expect(repo.by_id(task.id).status).to eq("done")
    end

    it "leaves the task canceled when the issue closes after it was taken off me" do
      task = tracked(:canceled, state: "unassigned")
      stub_known(issue(assignees: ["MDQ6VXNlcjE="], state: "CLOSED", stateReason: "COMPLETED"))
      sync

      expect(repo.by_id(task.id).status).to eq("canceled")
    end

    it "reopens the task when the issue is assigned back to me" do
      task = tracked(:canceled, state: "unassigned")
      stub_assigned(issue)
      sync

      expect(repo.by_id(task.id).status).to eq("open")
    end
  end

  describe "a task I closed by hand while its issue stays open" do
    it "stays closed" do
      task = tracked(:done)
      stub_assigned(issue)
      sync

      expect(repo.by_id(task.id).status).to eq("done")
    end
  end

  describe "an in progress task whose issue stays open" do
    it "stays in progress" do
      task = tracked(:in_progress)
      stub_assigned(issue)
      sync

      expect(repo.by_id(task.id).status).to eq("in_progress")
    end
  end

  describe "a deleted issue" do
    before { stub_vanished({ status: 410 }) }

    it "cancels its task" do
      task = tracked
      sync

      expect(repo.by_id(task.id).status).to eq("canceled")
    end

    it "stops asking GitHub about it once canceled", :aggregate_failures do
      tracked
      2.times { sync }

      expect(github_request(GitHubGraphQL::ISSUES_QUERY)).to have_been_made.once
      expect(a_request(:get, "#{api}/repos/aaronmallen/aaronmallen.me/issues/7")).to have_been_made.once
    end
  end

  describe "a gone issue assigned to me again" do
    def linked = Tasks::Slice["relations.task_sources"].where(remote_id: "I_seven").pluck(:task_id)

    %w[deleted moved].each do |state|
      it "reopens the task it had when it was #{state}", :aggregate_failures do
        task = tracked(:canceled, state:)
        stub_assigned(issue)
        sync

        expect(linked).to eq([task.id])
        expect(repo.by_id(task.id)).to have_attributes(status: "open", source: have_attributes(remote_state: "open"))
      end
    end

    it "lets the rest of the run import" do
      tracked(:canceled, state: "deleted")
      stub_assigned(issue, github_issue("I_eight", number: 8))
      sync

      expect(imported("I_eight").status).to eq("open")
    end

    it "lets the run clear a failure the last run left" do
      tracked(:canceled, state: "deleted")
      sync_state_mutations.record_failure(Blog::Types::SyncName["issues"], :rate_limited)
      stub_assigned(issue)
      sync

      expect(failure).to be_nil
    end

    it "is not asked about while it stays gone" do
      tracked(:canceled, state: "deleted")
      sync

      expect(github_request(GitHubGraphQL::ISSUES_QUERY)).not_to have_been_made
    end
  end

  describe "a tracked task deleted while the run waits on GitHub" do
    before do
      task = tracked
      stub_github(GitHubGraphQL::ASSIGNED_QUERY) do
        Tasks::Slice["operations.delete_task"].call(task.id)
        github_issue_search(issue(title: "Renamed"), github_issue("I_eight", number: 8))
      end
    end

    it "lets the rest of the run import" do
      sync

      expect(imported("I_eight").status).to eq("open")
    end

    it "lets the run clear a failure the last run left" do
      sync_state_mutations.record_failure(Blog::Types::SyncName["issues"], :rate_limited)
      sync

      expect(failure).to be_nil
    end
  end

  describe "an issue moved to another repository" do
    let(:moved_url) { "https://github.com/aaronmallen/elsewhere/issues/3" }

    before do
      stub_github(GitHubGraphQL::ISSUES_QUERY, github_missing_issue)
      stub_rest("aaronmallen/aaronmallen.me/issues/7",
                { status: 301, headers: { "Location" => "#{api}/repos/aaronmallen/elsewhere/issues/3" } })
      stub_rest("aaronmallen/elsewhere/issues/3", github_json(html_url: moved_url))
    end

    it "cancels the old task" do
      task = tracked
      sync

      expect(repo.by_id(task.id).status).to eq("canceled")
    end

    it "imports the moved issue as a new task when it is still mine", :aggregate_failures do
      tracked
      stub_assigned(github_issue("I_three", repo: "aaronmallen/elsewhere", number: 3))
      sync

      expect(imported("I_three")).to have_attributes(list: "external", status: "open")
      expect(imported("I_three").source.url).to eq(moved_url)
    end

    it "makes one new task when the job runs twice" do
      tracked
      stub_assigned(github_issue("I_three", repo: "aaronmallen/elsewhere", number: 3))
      2.times { sync }

      expect(Tasks::Slice["relations.task_sources"].count).to eq(2)
    end

    it "moves the issue's comments to the new task" do
      create(:task_comment, :synced, task_id: tracked(:canceled, state: "moved").id, remote_id: "IC_1")
      stub_assigned(github_issue("I_three", repo: "aaronmallen/elsewhere", number: 3,
                                            comments: { nodes: [github_comment("IC_1")] }))
      sync

      expect(comments(imported("I_three")).map(&:remote_id)).to eq(%w[IC_1])
    end

    it "imports nothing when the moved issue is no longer mine" do
      tracked
      sync

      expect(Tasks::Slice["relations.task_sources"].count).to eq(1)
    end
  end

  describe "a failed run" do
    it "records GitHub's refusal under issues", :aggregate_failures do
      stub_github(GitHubGraphQL::ASSIGNED_QUERY, github_rate_limited)
      sync

      expect(failure).to include(reason: "rate_limited")
      expect(imported).to be_nil
    end

    it "records a check GitHub fails rather than cancel the task", :aggregate_failures do
      task = tracked
      stub_vanished({ status: 500 })
      sync

      expect(failure).to include(reason: "github_failed")
      expect(repo.by_id(task.id).status).to eq("open")
    end

    it "records a search GitHub answers with no viewer rather than import", :aggregate_failures do
      search = { nodes: [issue], pageInfo: github_page_info(false, "issues-page-2") }
      stub_github(GitHubGraphQL::ASSIGNED_QUERY, github_json(data: { rateLimit: github_rate_limit, search: }))
      sync

      expect(failure).to include(reason: "github_failed", message: /no viewer/)
      expect(imported).to be_nil
    end

    it "records a check GitHub answers with no viewer rather than cancel the task", :aggregate_failures do
      task = tracked
      stub_github(GitHubGraphQL::ISSUES_QUERY, github_json(data: { nodes: [issue], rateLimit: github_rate_limit }))
      sync

      expect(failure).to include(reason: "github_failed", message: /no viewer/)
      expect(repo.by_id(task.id).status).to eq("open")
    end

    it "catches up on the next run from what it stored", :aggregate_failures do
      task = tracked
      stub_github(GitHubGraphQL::ISSUES_QUERY, { status: 500 }, github_issue_nodes(issue(state: "CLOSED")))
      2.times { sync }

      expect(failure).to be_nil
      expect(repo.by_id(task.id).status).to eq("done")
    end
  end

  describe "with no GitHub token" do
    before { disconnect_github }

    it "asks GitHub for nothing and records nothing", :aggregate_failures do
      sync

      expect(a_request(:any, %r{\A#{api}/})).not_to have_been_made
      expect(failure).to be_nil
    end
  end

  describe "when another run is already going" do
    let(:connection) { Tasks::Slice["db.rom"].gateways.fetch(:default).connection }
    let(:elsewhere) { Sequel.connect(connection.opts) }

    before { elsewhere.get(Sequel.function(:pg_try_advisory_lock, Tasks::Repos::TaskSourceRepo::SYNC_LOCK)) }

    after { elsewhere.disconnect }

    it "leaves the run to the one holding the lock", :aggregate_failures do
      sync

      expect(github_request(GitHubGraphQL::ASSIGNED_QUERY)).not_to have_been_made
      expect(failure).to be_nil
    end
  end
end
