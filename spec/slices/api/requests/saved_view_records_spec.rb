# frozen_string_literal: true

RSpec.describe "API saved view records", type: :request do
  def api_token = @api_token ||= API::Slice["operations.mint_token"].call(name: "Terminal").value!.fetch(:value)

  def at(day, hour = 12) = Blog::TimeZone.local_time(day.year, day.month, day.day, hour, 0)

  def commit_row(commit)
    {
      "kind" => "commit", "source_id" => commit.id, "date" => today.iso8601, "time" => "09:00",
      "name" => commit.message, "link" => nil, "repo" => commit.repo, "sha" => commit.sha,
      "additions" => commit.additions, "deletions" => commit.deletions, "status" => nil, "targets" => nil,
      "excerpt" => nil, "task_id" => nil, "decision_id" => nil, "worked_seconds" => nil, "tags" => [],
    }
  end

  def first_record(screen, **) = records(screen, **).dig("records", 0)

  def ids(answer) = answer.fetch("records").map { it.fetch("id") }

  def names(answer) = answer.fetch("records").map { it.fetch("name") }

  def next_window(id) = read(id, continue_to: read(id).fetch("continue_to"))

  def read(id, query = {})
    headers = { "HTTP_ACCEPT" => "application/json", "HTTP_AUTHORIZATION" => "Bearer #{api_token}" }
    get "/api/v1/saved_views/#{id}/records", query, headers
    JSON.parse(last_response.body)
  end

  def read_view(view) = { "id" => view.id, "name" => view.name, "screen" => view.screen, "filters" => view.filters }

  def records(screen = "tasks", query: {}, **filters) = read(create(:saved_view, screen:, filters:).id, query)

  def saved_rows(filters)
    view = create(:saved_view, screen: "activity", filters:)
    mcp_answer("read_saved_view", id: view.id).fetch("records").map { it.values_at("date", "name") }
  end

  def screen_rows(filters)
    get "/admin/activity", filters
    Capybara.string(last_response.body).all(".activity-day").flat_map do |day|
      day.all(".activity-event-name").map { [day.find(".activity-day-date")[:datetime], it.text] }
    end
  end

  def status = last_response.status

  def today = Blog::TimeZone.today

  describe "a tasks view" do
    it "answers the view, the tasks in its list and paging" do
      view = create(:saved_view, name: "Next", screen: "tasks", filters: { filter: "next" })
      task = create(:task)
      create(:task, :someday)

      expect(read(view.id).values_at("saved_view", "count", "partial", "records"))
        .to match([read_view(view), 1, false, [include("id" => task.id)]])
    end

    it "narrows by the tags and words in its search" do
      tagged = create(:task, title: "ship the deploy", tags: %w[ops])
      create(:task, title: "ship the deploy")
      create(:task, title: "other", tags: %w[ops])

      expect(ids(records(filter: "next", q: "tag:ops deploy"))).to eq([tagged.id])
    end

    it "reads today's sprint when no list is saved, giving each task its sprint day" do
      sprint = create(:sprint, sprint_date: today)
      task = create(:task, :in_sprint, sprint_id: sprint.id)
      create(:task)

      expect(records.fetch("records")).to match([include("id" => task.id, "sprint_on" => today.iso8601)])
    end

    it "reads the finished tasks on the completed tab" do
      done = create(:task, :done)
      create(:task)

      expect(ids(records(filter: "completed"))).to eq([done.id])
    end

    it "reads the planned sprints on the upcoming tab" do
      later = today + 3
      task = create(:task, :in_sprint, sprint_id: create(:sprint, sprint_date: later).id)

      expect(first_record("tasks", filter: "upcoming")).to include("id" => task.id, "sprint_on" => later.iso8601)
    end

    it "gives each task the JSON read_task gives, less its comments, record links and timeline" do
      task = create(:task, title: "linked", tags: %w[ops])
      create(:task_link, from_task_id: create(:task, :done).id, to_task_id: task.id)
      found = records(filter: "next").fetch("records")
      task_read = trusted(mcp_answer("read_task", id: task.id))

      expect(found).to eq([task_read.except("comments", "record_links", "timeline")])
    end

    it "pages as list_tasks does" do
      3.times { create(:task) }
      lower_page_size(:mcp, to: 2)

      expect([records(filter: "next"), records(filter: "next", query: { page: "2" })]).to match(
        [include("count" => 2, "partial" => true, "next_page" => 2), include("count" => 1, "partial" => false)],
      )
    end
  end

  describe "a posts view" do
    it "reads the posts in its status, each as the bulk post endpoints give it" do
      draft = create(:post, :draft, tags: %w[ruby])
      create(:post, :published)

      expect(records("posts", status: "draft").fetch("records"))
        .to eq([JSON.parse(API::Serializers::Post.new(Posts::Slice["queries.by_id"].call(draft.id)).serialize)])
    end

    it "reads every post when no status is saved" do
      create(:post, :draft)
      create(:post, :published)

      expect(records("posts").fetch("count")).to eq(2)
    end

    it "pages by page" do
      3.times { create(:post) }
      lower_page_size(:mcp, to: 2)

      expect(records("posts", query: { page: "2" })).to include("count" => 1, "partial" => false)
    end
  end

  describe "a journal view" do
    it "reads the entries matching its search, newest first, as read_journal_entry gives them" do
      older = create(:journal_entry, entry_date: today - 1, body: "a long run", tags: %w[health])
      newer = create(:journal_entry, body: "a short run", tags: %w[health])
      create(:journal_entry, body: "a long run")
      found = records("journal", q: "tag:health run").fetch("records")

      expect(found).to eq([newer, older].map { mcp_answer("read_journal_entry", id: it.id).except("record_links") })
    end

    it "reads back from its last day" do
      kept = create(:journal_entry, entry_date: today - 5)
      create(:journal_entry)

      expect(ids(records("journal", to: (today - 2).iso8601))).to eq([kept.id])
    end

    it "pages by day, taking continue_to for the next window" do
      stub_const("Blog::DayWindow::CAP", 1)
      entries = [0, 1, 2].map { create(:journal_entry, entry_date: today - it) }
      view = create(:saved_view, screen: "journal")

      expect([ids(read(view.id)), ids(next_window(view.id))]).to eq([[entries[0].id], [entries[1].id]])
    end
  end

  describe "an activity view" do
    it "reads the last week when no days are saved" do
      create(:commit, commit_date: today - 6, message: "kept")
      create(:commit, commit_date: today - 7, message: "dropped")

      expect(names(records("activity"))).to eq(["kept"])
    end

    it "reads only the kinds it ticks, inside its days" do
      create(:commit, commit_date: today - 20)
      entry = create(:journal_entry, entry_date: today - 20)
      create(:journal_entry, entry_date: today - 40)
      filters = { from: (today - 30).iso8601, to: (today - 10).iso8601, types: { journal: "1" } }

      expect(records("activity", **filters).fetch("records").map { it.fetch("source_id") }).to eq([entry.id])
    end

    it "narrows by repository and words" do
      create(:commit, repo: "aaronmallen/kept", message: "fix the deploy")
      create(:commit, repo: "aaronmallen/other", message: "fix the deploy")
      create(:commit, repo: "aaronmallen/kept", message: "tidy")

      expect(records("activity", q: "repo:kept deploy").fetch("count")).to eq(1)
    end

    it "gives a commit its whole message, repository, sha and lines" do
      commit = create(:commit, message: "Fix it\n\nThe long story", additions: 3, deletions: 1)

      expect(first_record("activity")).to eq(commit_row(commit))
    end

    it "gives a finished work session its task and the seconds it ran" do
      task = create(:task, title: "Write it", tags: %w[ops])
      create(:work_session, task_id: task.id, started_at: at(today, 9), ended_at: at(today, 10))

      expect(first_record("activity", types: { session: "1" }))
        .to include("name" => "Write it", "task_id" => task.id, "worked_seconds" => 3600, "tags" => %w[ops])
    end

    it "gives a decision event its decision, what happened and why" do
      decision = create(:decision, title: "Pick a queue")
      create(:decision_event, decision_id: decision.id, kind: "dropped", reason: "Not needed", created_at: at(today))

      expect(first_record("activity", types: { decision: "1" }).values_at("name", "status", "excerpt", "decision_id"))
        .to eq(["Pick a queue", "dropped", "Not needed", decision.id])
    end

    it "gives a comment on a decision its text and the decision's title" do
      decision = create(:decision, title: "Pick a queue")
      create(:decision_comment, decision_id: decision.id, body: "Leaning on Sidekiq", created_at: at(today))

      expect(first_record("activity", types: { decision_comment: "1" }))
        .to include("name" => "Leaning on Sidekiq", "excerpt" => "Pick a queue", "decision_id" => decision.id)
    end

    it "starts from its saved day and pages back by continue_to" do
      stub_const("Blog::DayWindow::CAP", 1)
      [0, 1, 2].map { create(:commit, commit_date: today - it, message: "day #{it}") }
      view = create(:saved_view, screen: "activity", filters: { day: (today - 1).iso8601 })

      expect([names(read(view.id)), names(next_window(view.id))]).to eq([["day 1"], ["day 2"]])
    end

    describe "beside the admin screen" do
      let(:filters) do
        {
          from: (today - 30).iso8601, to: (today - 10).iso8601, day: (today - 12).iso8601,
          types: { commit: "1", journal: "1" },
        }
      end

      before do
        sign_in_to_admin
        [11, 12, 15, 31].each { create(:commit, commit_date: today - it, message: "commit #{it}") }
        create(:journal_entry, entry_date: today - 14, body: "journal 14")
        create(:post, :published, title: "post 13", published_at: at(today - 13))
      end

      it "covers the days and kinds the screen shows for the same filters" do
        shown = [[12, "commit 12"], [14, "journal 14"], [15, "commit 15"]].map do |ago, name|
          [(today - ago).iso8601, name]
        end

        expect([screen_rows(filters), saved_rows(filters)]).to eq([shown, shown])
      end
    end
  end

  describe "a filter the screen no longer knows" do
    it "reads as if the filter were left at its default" do
      create(:post, :draft)
      create(:post, :published)

      expect(records("posts", state: "draft").fetch("count")).to eq(2)
    end

    it "leaves the filter out of the view it answers" do
      expect(records("posts", state: "draft").dig("saved_view", "filters")).to eq({})
    end

    it "falls back to the default for a value the screen no longer takes" do
      sprint = create(:sprint, sprint_date: today)
      task = create(:task, :in_sprint, sprint_id: sprint.id)
      create(:task)

      expect(ids(records(filter: "inbox"))).to eq([task.id])
    end
  end

  it "answers a missing view with a 404" do
    expect([read(404), status]).to eq([{ "error" => "not_found", "message" => "no saved view has the ID 404" }, 404])
  end

  it "refuses a continue_to that is not a day with a 422" do
    expect([read(create(:saved_view).id, continue_to: "soon").fetch("errors"), status])
      .to eq([{ "continue_to" => ["give continue_to as a day, such as 2026-01-01"] }, 422])
  end

  it "answers a failure to open today's sprint with a 500" do
    failing = instance_double(Tasks::Operations::CurrentSprint, call: Dry::Monads::Failure(:not_found))
    replace_component("tasks.operations.current_sprint", failing)

    expect([records, status]).to eq([{ "error" => "failed", "message" => "could not open today's sprint" }, 500])
  end

  describe "the read_saved_view tool" do
    before do
      create(:task, tags: %w[ops])
      create(:post, :draft, tags: %w[ruby])
      create(:journal_entry, body: "a run")
      create(:commit)
    end

    {
      "activity" => { types: { commit: "1" } },
      "journal" => { q: "run" },
      "posts" => { status: "draft" },
      "tasks" => { filter: "next" },
    }.each do |screen, filters|
      it "answers a #{screen} view as the endpoint does" do
        view = create(:saved_view, screen:, filters:)

        expect(trusted(mcp_answer("read_saved_view", id: view.id))).to eq(read(view.id))
      end
    end

    it "pages as the endpoint does" do
      2.times { create(:task) }
      lower_page_size(:mcp, to: 2)
      view = create(:saved_view, filters: { filter: "next" })

      expect(trusted(mcp_answer("read_saved_view", id: view.id, page: 2))).to eq(read(view.id, page: "2"))
    end

    it "refuses a missing view with the message the endpoint gives" do
      expect(mcp_text("read_saved_view", id: 404)).to eq(read(404).fetch("message"))
    end

    it "marks the refusal as an error" do
      expect(mcp_call("read_saved_view", id: 404).fetch("isError")).to be(true)
    end
  end
end
