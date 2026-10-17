# frozen_string_literal: true

RSpec.describe Tasks::Jobs::SyncIssues do
  let(:repo) { Tasks::Slice["repos.task_queries"] }
  let(:url) { "https://github.com/aaronmallen/aaronmallen.me/issues/7" }

  def another_issue = github_issue("I_eight", number: 8)
  def api = "https://api.github.com"
  def comment(id, **) = github_comment("IC_#{id}", **)
  def comments(task = imported) = Tasks::Slice["repos.task_comment_queries"].for_task(task.id)

  before do
    connect_github_token
    stub_assigned
    stub_known
  end

  def copied(id, at:, author: "octocat")
    { author:, body: "Looks good", created_at: at, provider: "github", remote_id: "IC_#{id}",
      url: "https://github.com/aaronmallen/aaronmallen.me/issues/7#issuecomment-#{id}" }
  end

  def discussed(*nodes, **) = issue(comments: { nodes: }, **)

  def failure = sync_state_queries.failure(Blog::Types::SyncName["issues"])

  def imported(id = "I_seven") = repo.by_id(sources.at("github", id).pluck(:task_id).first)

  def issue(id = "I_seven", **) = github_issue(id, number: 7, **)

  def page_of(number, **) = github_issue_search(github_issue("I_#{number}", number:), **)

  def searched = github_request(GitHubGraphQL::ASSIGNED_QUERY)

  def sources = Tasks::Slice["relations.task_sources"]

  def stub_assigned(*nodes, &during)
    stub_github(GitHubGraphQL::ASSIGNED_QUERY) do
      during&.call
      github_issue_search(*nodes)
    end
  end

  def stub_known(*nodes)
    stub_github(GitHubGraphQL::ISSUES_QUERY) do |request|
      ids = JSON.parse(request.body).dig("variables", "ids")
      github_issue_nodes(*ids.map { |id| nodes.find { it[:id] == id } })
    end
  end

  def stub_pages(*pages) = stub_github(GitHubGraphQL::ASSIGNED_QUERY, *pages)

  def stub_rest(path, response) = stub_request(:get, "#{api}/repos/#{path}").to_return(response)

  def stub_vanished(response, repo: github_json(full_name: "aaronmallen/aaronmallen.me"))
    stub_github(GitHubGraphQL::ISSUES_QUERY, github_missing_issue)
    stub_rest("aaronmallen/aaronmallen.me/issues/7", response)
    stub_rest("aaronmallen/aaronmallen.me", repo)
  end

  def sync = described_class.new.perform("github")

  def taken_off(**) = issue(assignees: ["MDQ6VXNlcjE="], **)

  def tracked(*traits, state: "open", checked_at: nil, **)
    task = create(:task, *traits, list: "external", **)

    create(:task_source, remote_id: "I_seven", url:, remote_state: state, checked_at:, task:)
      .then { repo.by_id(it.task_id) }
  end

  it_behaves_like(
    "an issue sync", provider: "github", sync_name: "issues", body: :body, reference: "aaronmallen/aaronmallen.me#7",
  )

  describe "a new issue assigned to me" do
    before { stub_assigned(issue(title: "Sync my issues", body: "Keep them in step")) }

    it "is found by a search of every repository for open issues, not pull requests, assigned to me" do
      sync

      expect(github_request("is:issue is:open assignee:@me")).to have_been_made
    end
  end

  describe "several issues already tracked" do
    before do
      %w[I_one I_two I_three].each do |id|
        create(:task_source, remote_id: id, url: "#{url}-#{id}", task: create(:task, list: "external"))
      end
      stub_assigned(*%w[I_one I_two I_three].map { github_issue(it) })
    end

    it "loads their tasks in one query" do
      tasks = counting { sync }.grep(/\ASELECT "tasks"."id", "tasks"."title"/)

      expect(tasks.size).to eq(1)
    end

    it "loads only the task columns the sync reads" do
      tasks = counting { sync }.grep(/\ASELECT "tasks"."id", "tasks"."title"/)

      expect(tasks.first).to start_with('SELECT "tasks"."id", "tasks"."title", "tasks"."note", "tasks"."status" FROM')
    end
  end

  describe "issues that did not change since the last run" do
    def held(*numbers, **fields)
      numbers.map { github_issue("I_#{it}", number: it, comments: { nodes: [comment(it)] }, **fields) }
    end

    def hold(*numbers)
      stub_assigned(*held(*numbers))
      sync
    end

    def opened = counting(/\ASAVEPOINT/) { sync }.size

    it "loads their synced comments in one query" do
      hold(1, 2, 3)

      expect(counting { sync }.grep(/\ASELECT "task_comments"/).size).to eq(1)
    end

    it "makes no write to their tasks, sources or comments" do
      hold(1, 2, 3)

      expect(counting { sync }.grep(/\A(INSERT INTO|UPDATE|DELETE FROM) "task/)).to be_empty
    end

    it "opens a transaction only for the one that changed" do
      hold(1, 2, 3)
      still = opened
      stub_assigned(*held(1, 3), *held(2, title: "Renamed"))

      expect(opened).to eq(still + 1)
    end

    it "makes no more queries over three than over one" do
      hold(1)
      one = counting(/./) { sync }.size
      hold(1, 2, 3)

      expect(counting(/./) { sync }.size).to eq(one)
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

    it "arrives unseen with its tags" do
      stub_assigned(labeled("Bug Fix"))
      sync

      expect(imported.source.seen_at).to be_nil
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
      Tasks::Slice["repos.task_mutations"].replace_tags(imported.id, %w[ruby])
      sync

      expect(imported.tags.map(&:name)).to eq(%w[ruby])
    end
  end

  describe "a new issue from a repo with rules that hold projects" do
    let(:blog) { create(:project, :private) }
    let(:site) { create(:project, :archived) }

    before do
      rule("aaronmallen/aaronmallen.me", projects: [site.id])
      rule("aaronmallen/*", tags: "ruby", projects: [blog.id])
    end

    def project_ids = Tasks::Slice["relations.tasks"].where(id: imported.id).exclude(project_id: nil).pluck(:project_id)

    def rule(pattern, tags: "", projects: [])
      Tasks::Slice["operations.save_task_rule"].call({ pattern:, tags:, projects: }).value!
    end

    def unlink(project_id) = Links::Slice["operations.unlink_records"].call("task", imported.id, "project", project_id)

    it "takes the project of the first rule it matches, private or archived" do
      stub_assigned(issue)
      sync

      expect(project_ids).to eq([site.id])
    end

    it "takes no project from a project's repo alone" do
      create(:project, repo: "octocat/pod")
      stub_assigned(issue(repo: "octocat/pod"))
      sync

      expect(project_ids).to be_empty
    end

    describe "and a rule for its exact repo made after the owner's" do
      let(:pod) { create(:project) }

      before { rule("aaronmallen/pod", projects: [pod.id]) }

      it "takes the exact rule's project over the owner rule's" do
        stub_assigned(issue(repo: "AaronMallen/Pod"))
        sync

        expect(project_ids).to eq([pod.id])
      end
    end

    it "takes no project when the issue comes from another owner" do
      stub_assigned(issue(repo: "octocat/aaronmallen.me"))
      sync

      expect(project_ids).to be_empty
    end

    it "keeps a rule's project off on the next sync when I removed it" do
      stub_assigned(issue)
      sync
      unlink(site.id)
      sync

      expect(project_ids).to be_empty
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
  end

  describe "an issue's comments" do
    def sync_twice(first, second)
      stub_assigned(first)
      sync
      stub_assigned(second)
      sync
    end

    it "arrive with no author from a deleted account" do
      stub_assigned(discussed(github_comment("IC_1", author: nil)))
      sync

      expect(comments.map(&:author)).to eq([nil])
    end

    it "take an edit made on GitHub" do
      sync_twice(discussed(github_comment("IC_1")), discussed(github_comment("IC_1", body: "Edited")))

      expect(comments.map(&:body)).to eq(%w[Edited])
    end

    it "lose one deleted on GitHub" do
      sync_twice(discussed(github_comment("IC_1"), github_comment("IC_2")), discussed(github_comment("IC_2")))

      expect(comments.map(&:remote_id)).to eq(%w[IC_2])
    end

    it "keep every held comment and take the new ones when GitHub cuts the list short" do
      cut = discussed(github_comment("IC_2"), github_comment("IC_3"))
      cut[:comments][:pageInfo] = { hasNextPage: true }
      sync_twice(discussed(github_comment("IC_1"), github_comment("IC_2")), cut)

      expect(comments.map(&:remote_id)).to eq(%w[IC_1 IC_2 IC_3])
    end

    it "skip a comment with nothing to show once cleaned" do
      stub_assigned(discussed(github_comment("IC_1", body: "\u0000 "), github_comment("IC_2", body: "Fine\u0000")))
      sync

      expect(comments.map { [it.remote_id, it.body] }).to eq([%w[IC_2 Fine]])
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
    let(:client) { Tasks::Slice["github.client"] }
    let(:found) { [] }

    def collect(issues) = issues.tap { found.concat(it.respond_to?(:items) ? it.items : it) }

    def gather(name) = allow(client).to(receive(name).and_wrap_original { |read, *args| collect(read.call(*args)) })

    def handed_over(id = "I_seven")
      gather(:assigned_issues)
      gather(:issues)
      described_class.new(github: client).perform("github")
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

  describe "an issue closed on GitHub when its task cannot settle" do
    before do
      replace_component("operations.cancel_task", ->(*, **) { Failure(:invalid) })
      stub_known(issue(state: "CLOSED", stateReason: "NOT_PLANNED"))
    end

    def run_failing
      sync
    rescue Dry::Monads::UnwrapError
      nil
    end

    it "records the crash and leaves the source to try again", :aggregate_failures do
      task = tracked
      run_failing

      expect(failure).to include(reason: "crashed")
      expect(repo.by_id(task.id).status).to eq("open")
      expect(sources.where(task_id: task.id).pluck(:remote_state)).to eq(["open"])
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

    def closed_yesterday(*numbers)
      checked_at = Time.now - day - 60
      nodes = numbers.map { github_issue("I_#{it}", number: it, state: "CLOSED", stateReason: "COMPLETED") }
      nodes.each do |node|
        task = create(:task, :done, list: "external", title: node[:title], note: node[:body])
        create(:task_source, remote_id: node[:id], url: node[:url], remote_state: "completed", checked_at:, task:)
      end
      stub_known(*nodes)
    end

    it "restamps every unchanged one in one update", :aggregate_failures do
      closed_yesterday(1, 2, 3)

      expect(counting { sync }.grep(/\AUPDATE "task_sources"/).size).to eq(1)
      expect(sources.pluck(:checked_at)).to all(be_within(5).of(Time.now))
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
    it "reads the synced links of every such issue in one query" do
      taken = (1..3).map { github_issue("I_#{it}", number: it, assignees: ["MDQ6VXNlcjE="]) }
      taken.each { create(:task_source, remote_id: it[:id], url: it[:url], task: create(:task, list: "external")) }
      stub_known(*taken)

      expect(counting { sync }.grep(/FROM "task_links" WHERE .*"synced"/).size).to eq(1)
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

  describe "an issue in a repo the token no longer sees" do
    before { stub_vanished({ status: 404 }, repo: { status: 404 }) }

    it "leaves its task and source alone", :aggregate_failures do
      task = tracked
      sync

      expect(repo.by_id(task.id).status).to eq("open")
      expect(sources.pluck(:remote_state)).to eq(%w[open])
    end

    it "asks after the repo once for all its issues" do
      tracked
      create(:task_source, provider: "github", remote_id: "I_eight", url: url.sub(/7\z/, "8"))
      stub_rest("aaronmallen/aaronmallen.me/issues/8", { status: 404 })
      sync

      expect(a_request(:get, "#{api}/repos/aaronmallen/aaronmallen.me")).to have_been_made.once
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

  describe "a run that crashes" do
    before { replace_component("operations.sync_issues", ->(*) { raise KeyError, "key not found: :id" }) }

    def run_crashing
      sync
    rescue KeyError
      nil
    end

    it "records the crash where the admin reads it" do
      run_crashing

      expect(failure).to include(reason: "crashed", message: "key not found: :id")
    end

    it "still raises, so the error reaches error tracking" do
      expect { sync }.to raise_error(KeyError, /key not found/)
    end
  end
end
