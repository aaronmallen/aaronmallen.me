# frozen_string_literal: true

RSpec.shared_examples "an issue sync" do |provider:, sync_name:, body:, reference:|
  describe "a new issue assigned to me" do
    before { stub_assigned(issue(title: "Sync my work", body => "Keep it in step")) }

    it "becomes a task on the external list with no tags", :aggregate_failures do
      sync

      expect(imported).to have_attributes(list: "external", note: "Keep it in step", sprint_id: nil,
                                          status: "open", title: "Sync my work")
      expect(imported.tags).to be_empty
    end

    it "links the task to its issue" do
      sync

      expect(imported.source).to have_attributes(provider:, remote_id: issue[:id], url:)
    end

    it "arrives unseen" do
      sync

      expect(imported.source.seen_at).to be_nil
    end

    it "makes one task when the job runs twice" do
      2.times { sync }

      expect(sources.where(remote_id: issue[:id]).count).to eq(1)
    end

    it "clears a failure the last run left" do
      sync_state_mutations.record_failure(Blog::Types::SyncName[sync_name], :rate_limited)
      sync

      expect(failure).to be_nil
    end
  end

  describe "more than ten pages of assigned issues" do
    before { stub_pages(*Array.new(12) { |n| page_of(n + 1, more: n < 11, cursor: "page-#{n + 2}") }) }

    it "reads every page and imports every issue", :aggregate_failures do
      sync

      expect(searched).to have_been_made.times(12)
      expect(sources.where(provider:).count).to eq(12)
    end

    it "records no failure" do
      sync

      expect(failure).to be_nil
    end
  end

  describe "a listing whose next page cursor never moves" do
    before { stub_pages(page_of(1, more: true, cursor: "page-2")) }

    it "stops once the cursor comes back and records the page limit", :aggregate_failures do
      sync

      expect(searched).to have_been_made.times(2)
      expect(failure).to include(reason: "page_limit")
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
      Tasks::Slice["repos.task_mutations"].replace_tags(imported.id, [])
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

  describe "a new issue with labels filed into a project" do
    let(:project) { create(:project) }

    before do
      create(:tag, :private, name: "bug-fix")
      Tasks::Slice["operations.save_task_rule"].call({ pattern: "aaronmallen/*", provider:, projects: [project.id] })
    end

    def events = Tasks::Slice["relations.task_events"].for_task(imported.id).to_a

    def labeled(*names) = issue(labels: { nodes: names.map { { name: it } } })

    def project_tags = imported.tags.map { [it.name, it.scope, it.project_id] }

    it "imports with its labels as tags in the project, made there when missing" do
      create(:tag, scope: "project", project_id: project.id, name: "needs-review")
      stub_assigned(labeled("Bug Fix", "needs review"))
      sync

      expect(project_tags).to contain_exactly(["bug-fix", "project", project.id],
                                              ["needs-review", "project", project.id])
    end

    it "takes a label added after import as a project tag on the next sync" do
      stub_assigned(labeled)
      sync
      stub_assigned(labeled("Bug Fix"))
      sync

      expect(project_tags).to eq([["bug-fix", "project", project.id]])
    end

    it "records a tag a later sync adds in the task history" do
      stub_assigned(labeled)
      sync
      stub_assigned(labeled("Bug Fix"))
      sync

      expect(events.map { [it[:kind], it[:tag_name]] }).to eq([%w[tagged bug-fix]])
    end

    it "keeps the tag once its label goes" do
      stub_assigned(labeled("Bug Fix"))
      sync
      stub_assigned(labeled)
      sync

      expect(project_tags).to eq([["bug-fix", "project", project.id]])
    end

    it "makes no write to a task that holds every label" do
      stub_assigned(labeled("Bug Fix"))
      sync

      expect(counting { sync }.grep(/\A(INSERT INTO|UPDATE|DELETE FROM) "(task|tag)/)).to be_empty
    end
  end

  describe "an issue whose title is blank once cleaned" do
    it "keeps that title while the issue's title stays blank" do
      stub_assigned(issue(title: "\u0000"))
      sync
      stub_assigned(issue(title: " \u0000 ", body => "New body"))
      sync

      expect(imported).to have_attributes(note: "New body", title: reference)
    end

    it "takes a real title once the issue has one" do
      stub_assigned(issue(title: "\u0000"))
      sync
      stub_assigned(issue(title: "Sync my work"))
      sync

      expect(imported.title).to eq("Sync my work")
    end
  end

  describe "an issue's comments" do
    let(:at) { Time.utc(2026, 9, 28, 12) }

    def remote(comment) = comment.to_h.slice(:author, :body, :created_at, :provider, :remote_id, :url)

    it "arrive on its task with author, body, time and link" do
      stub_assigned(discussed(comment("1", at:), comment("2", author: "sam", at: at + 60)))
      sync

      expect(comments.map { remote(it) }).to eq([copied("1", at:), copied("2", author: "sam", at: at + 60)])
    end

    it "arrive on a task already tracked" do
      task = tracked
      stub_assigned(discussed(comment("1")))
      sync

      expect(comments(task).map(&:remote_id)).to eq([comment("1")[:id]])
    end

    it "add no rows and change nothing when synced again unchanged", :aggregate_failures do
      stub_assigned(discussed(comment("1"), comment("2")))
      before = sync.then { comments.map(&:to_h) }
      sync

      expect(comments.map(&:to_h)).to eq(before)
      expect(Tasks::Slice["relations.task_comments"].count).to eq(2)
    end

    it "leave my own comments alone" do
      task = tracked
      mine = create(:task_comment, task_id: task.id)
      stub_assigned(discussed(comment("1")))
      sync

      expect(comments(task).map(&:id)).to include(mine.id)
    end

    it "stop coming to a task I finished" do
      task = tracked(:done)
      stub_assigned(discussed(comment("1")))
      sync

      expect(comments(task)).to be_empty
    end
  end

  describe "an issue taken off me" do
    it "cancels its task" do
      task = tracked
      stub_known(taken_off)
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

  describe "a tracked task deleted while the run waits on the provider" do
    before do
      task = tracked
      stub_assigned(issue(title: "Renamed"), another_issue) { Tasks::Slice["operations.delete_task"].call(task.id) }
    end

    it "lets the rest of the run import" do
      sync

      expect(imported(another_issue[:id]).status).to eq("open")
    end

    it "lets the run clear a failure the last run left" do
      sync_state_mutations.record_failure(Blog::Types::SyncName[sync_name], :rate_limited)
      sync

      expect(failure).to be_nil
    end
  end

  describe "when another run is already going" do
    let(:elsewhere) { Sequel.connect(Tasks::Slice["db.rom"].gateways.fetch(:default).connection.opts) }

    before do
      lock = Blog::DB::Relation.lock_key(Tasks::Repos::TaskSourceMutations::SYNC_LOCKS.fetch(provider))
      elsewhere.get(Sequel.function(:pg_try_advisory_lock, lock))
    end

    after { elsewhere.disconnect }

    it "leaves the run to the one holding the lock", :aggregate_failures do
      sync

      expect(searched).not_to have_been_made
      expect(failure).to be_nil
    end
  end
end
