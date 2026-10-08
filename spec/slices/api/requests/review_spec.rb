# frozen_string_literal: true

RSpec.describe "API review", type: :request do
  let(:wednesday) { Date.new(2026, 9, 16) }

  def api_token = @api_token ||= API::Slice["operations.mint_token"].call(name: "Terminal").value!.fetch(:value)

  def at(day, hour = 12, minute = 0) = Blog::TimeZone.local_time(day.year, day.month, day.day, hour, minute)

  def carried(*days) = create(:task, :in_sprint).tap { |task| days.each { carry(task, it) } }

  def carry(task, from, to = from + 1, at: at(to))
    create(:task_event, :carried, task_id: task.id, from_sprint_on: from, to_sprint_on: to, occurred_at: at)
  end

  def close(kind, day, title: "Pick a store", decision: create(:decision, title:), chosen: nil, hour: 12)
    option_id = chosen && create(:decision_option, decision_id: decision.id, title: chosen).id
    create(:decision_event, decision_id: decision.id, kind:, option_id:, reason: "Settled", created_at: at(day, hour))
    decision
  end

  def fill(day, title: "Finish the review screen")
    done = create(:task, :done, title:, completed_at: at(day), worked_seconds: 5400)
    create(:work_session, task_id: done.id, started_at: at(day, 9), ended_at: at(day, 10))
    { done:, carried: carried(day - 2, day - 1, day) }
  end

  def read(**query)
    headers = { "HTTP_ACCEPT" => "application/json", "HTTP_AUTHORIZATION" => "Bearer #{api_token}" }
    get "/api/v1/review", query, headers
    JSON.parse(last_response.body)
  end

  def stats
    sign_in_to_admin
    get "/admin/review", day: wednesday.iso8601
    sub = Capybara.string(last_response.body).find(".page-head-sub").text
    sub.split(": ", 2).last.split(", ").map { it.sub(/ \S+\z/, "") }
  end

  def status = last_response.status

  def today = Blog::TimeZone.today

  def work(from, to) = create(:work_session, task_id: create(:task).id, started_at: from, ended_at: to)

  describe "a week with records" do
    let!(:filled) { fill(wednesday) }
    let!(:records) do
      {
        post: create(:post, :published, title: "A post that went out", published_at: at(wednesday)),
        social_post: create(:social_post, :posted, posted_at: at(Date.new(2026, 9, 18))),
        entry: create(:journal_entry, entry_date: Date.new(2026, 9, 14), body: "one two three"),
        resolved: close("resolved", Date.new(2026, 9, 15), title: "Pick a queue", chosen: "Sidekiq"),
        dropped: close("dropped", Date.new(2026, 9, 18), title: "Move to a VPS"),
      }
    end
    let(:review) { read(day: "2026-09-17") }

    before do
      create(:journal_entry, entry_date: Date.new(2026, 9, 15), body: "four five")
      create(:commit, repo: "aaronmallen/one", commit_date: wednesday, additions: 10, deletions: 2)
    end

    it "names the week that holds the day" do
      expect(review.values_at("period", "from", "to")).to eq(%w[week 2026-09-14 2026-09-20])
    end

    it "totals the tasks done, the tasks carried, the time worked and the commits" do
      expect(review.fetch("totals")).to eq("done" => 1, "carried" => 1, "worked_seconds" => 3600, "commits" => 1)
    end

    it "groups the tasks done by day" do
      task = {
        "id" => filled[:done].id, "title" => "Finish the review screen", "worked_seconds" => 5400,
        "contributors" => [{ "kind" => "owner" }],
      }

      expect(review.fetch("done")).to eq([{ "date" => "2026-09-16", "tasks" => [task] }])
    end

    it "lists the tasks carried with the days they slipped" do
      task = filled[:carried]

      expect(review.fetch("carried"))
        .to eq([{ "id" => task.id, "title" => task.title, "carried_count" => 3, "sprint_on" => "2026-09-16" }])
    end

    it "lists the posts and social posts that went out" do
      expect(review.values_at("posts", "social_posts").map { it.map { it.values_at("id", "date") } })
        .to eq([[[records[:post].id, "2026-09-16"]], [[records[:social_post].id, "2026-09-18"]]])
    end

    it "lists the journal entries" do
      journal = review.fetch("journal")
      first = { "id" => records[:entry].id, "date" => "2026-09-14", "name" => "one two three" }

      expect(journal.fetch("entries").first).to eq(first)
    end

    it "counts the journal's words and streak" do
      expect(review.fetch("journal").slice("words", "streak")).to eq("words" => 5, "streak" => 2)
    end

    it "totals the commits by repo" do
      expect(review.fetch("commits"))
        .to eq([{ "repo" => "aaronmallen/one", "commits" => 1, "additions" => 10, "deletions" => 2 }])
    end

    it "lists the decisions resolved or dropped, with the option chosen" do
      resolved = [records[:resolved].id, "resolved", "Sidekiq", "Settled", "2026-09-15"]
      dropped = [records[:dropped].id, "dropped", nil, "Settled", "2026-09-18"]

      expect(review.fetch("decisions").map { it.values_at("id", "outcome", "chosen", "reason", "date") })
        .to eq([resolved, dropped])
    end

    it "gives the decisions the admin screen shows for the same week" do
      sign_in_to_admin
      get "/admin/review", day: wednesday.iso8601
      shown = Capybara.string(last_response.body).all("#review-decisions a.li-title").map(&:text)

      expect(mcp_answer("read_review", day: wednesday.iso8601).fetch("decisions").map { it.fetch("title") })
        .to eq(shown)
    end

    it "gives the time worked on every day of the week" do
      expect(review.fetch("worked").map { it.values_at("date", "seconds") })
        .to eq((Date.new(2026, 9, 14)..Date.new(2026, 9, 20)).map { [it.iso8601, it == wednesday ? 3600 : 0] })
    end

    it "gives the numbers the admin screen shows for the same week" do
      totals = mcp_answer("read_review", day: wednesday.iso8601).fetch("totals")
      worked = Blog::Helpers::Figures.hours(totals.fetch("worked_seconds"))
      shown = [*totals.values_at("done", "carried"), worked, totals.fetch("commits")]

      expect(shown.map(&:to_s)).to eq(stats)
    end
  end

  describe "a month" do
    let(:review) { read(period: "month", day: "2026-09-16") }

    before do
      fill(Date.new(2026, 8, 31), title: "Done in August")
      fill(Date.new(2026, 9, 1), title: "Done on the first")
      fill(Date.new(2026, 9, 30), title: "Done on the last")
    end

    it "runs across the calendar month" do
      expect(review.values_at("period", "from", "to")).to eq(%w[month 2026-09-01 2026-09-30])
    end

    it "groups the tasks done inside it" do
      expect(review.fetch("done").map { it.fetch("date") }).to eq(%w[2026-09-01 2026-09-30])
    end

    it "gives the time worked on every day of the month" do
      expect(review.fetch("worked").size).to eq(30)
    end
  end

  describe "the edges of a week" do
    let(:review) { read(day: wednesday.iso8601) }

    def carries = review.fetch("carried").map { it.values_at("id", "carried_count", "sprint_on") }

    def seconds_on(*days) = review.fetch("worked").to_h { it.values_at("date", "seconds") }.values_at(*days)

    it "groups the tasks done by the local day they closed" do
      late = create(:task, :done, completed_at: at(Date.new(2026, 9, 15), 23, 30))
      early = create(:task, :done, completed_at: at(Date.new(2026, 9, 17), 0, 30))

      expect(review.fetch("done").map { [it.fetch("date"), it.fetch("tasks").map { it.fetch("id") }] })
        .to eq([["2026-09-15", [late.id]], ["2026-09-17", [early.id]]])
    end

    it "leaves out tasks closed outside the week and canceled tasks" do
      create(:task, :done, completed_at: at(Date.new(2026, 9, 13), 23, 59))
      create(:task, :done, completed_at: at(Date.new(2026, 9, 21), 0, 1))
      create(:task, :canceled, completed_at: at(wednesday))

      expect(review.fetch("done")).to be_empty
    end

    it "names the last sprint each task left in the week" do
      task = carried(Date.new(2026, 9, 14), wednesday)

      expect(carries).to eq([[task.id, 2, "2026-09-16"]])
    end

    it "counts only the carries out of sprints in the week" do
      task = carried(Date.new(2026, 9, 11), Date.new(2026, 9, 18), Date.new(2026, 9, 21))

      expect(carries).to eq([[task.id, 1, "2026-09-18"]])
    end

    it "keeps a task carried out of the week after it is carried again the next week" do
      task = carried(Date.new(2026, 9, 18), Date.new(2026, 9, 21))
      next_week = read(day: "2026-09-23").fetch("carried").map { it.values_at("id", "sprint_on") }

      expect([carries, next_week]).to eq([[[task.id, 1, "2026-09-18"]], [[task.id, "2026-09-21"]]])
    end

    it "leaves out a task carried before the week and later scheduled into it" do
      task = create(:task, list: nil, sprint_id: create(:sprint, sprint_date: wednesday).id, carried_count: 3)
      [Date.new(2026, 9, 1), Date.new(2026, 9, 2), Date.new(2026, 9, 3)].each { carry(task, it) }

      expect(review.fetch("carried")).to be_empty
    end

    describe "moves that are not carries" do
      let(:task) { create(:task, :in_sprint) }

      it "leaves out a task scheduled ahead into a later sprint" do
        carry(task, wednesday, Date.new(2026, 9, 18), at: at(wednesday))

        expect(review.fetch("carried")).to be_empty
      end

      it "leaves out a task moved back to an earlier sprint" do
        carry(task, wednesday, Date.new(2026, 9, 15))

        expect(review.fetch("carried")).to be_empty
      end

      it "leaves out a task moved off its sprint onto a list" do
        create(:task_event, :carried, task_id: task.id, from_sprint_on: wednesday, to_list: "next")

        expect(review.fetch("carried")).to be_empty
      end
    end

    it "leaves out drafts and what went out in another week" do
      create(:post, :draft)
      create(:post, :published, published_at: at(Date.new(2026, 9, 21)))
      create(:social_post, :draft)
      create(:social_post, :posted, posted_at: at(Date.new(2026, 9, 13)))

      expect(review.values_at("posts", "social_posts")).to eq([[], []])
    end

    it "gives no journal streak for a week with no entries" do
      expect(review.dig("journal", "streak")).to eq(0)
    end

    it "lists a decision closed twice in the week once, with how it last closed" do
      decision = close("resolved", Date.new(2026, 9, 14), chosen: "Redis")
      create(:decision_event, decision_id: decision.id, kind: "reopened", reason: "Too costly",
                              created_at: at(Date.new(2026, 9, 15)))
      close("dropped", wednesday, decision:)

      expect(review.fetch("decisions").map { it.values_at("id", "outcome") }).to eq([[decision.id, "dropped"]])
    end

    it "leaves out decisions closed in another week and events that close nothing" do
      close("resolved", Date.new(2026, 9, 13), chosen: "Redis", hour: 23)
      close("dropped", Date.new(2026, 9, 21), hour: 0)
      create(:decision_event, kind: "opened", created_at: at(wednesday))

      expect(review.fetch("decisions")).to be_empty
    end

    it "splits a session that crosses midnight between both days" do
      work(at(Date.new(2026, 9, 15), 23), at(wednesday, 1, 30))

      expect(seconds_on("2026-09-15", "2026-09-16")).to eq([3600, 5400])
    end

    it "counts only the part of a session inside the week" do
      work(at(Date.new(2026, 9, 13), 23), at(Date.new(2026, 9, 14), 1))

      expect([seconds_on("2026-09-14"), review.dig("totals", "worked_seconds")]).to eq([[3600], 3600])
    end
  end

  describe "a month with records on each edge" do
    let(:review) { read(period: "month", day: "2026-09-16") }
    let(:inside) { %w[2026-09-01 2026-09-30] }

    def dates(found) = found.map { it.fetch("date") }

    before do
      [Date.new(2026, 8, 31), Date.new(2026, 9, 1), Date.new(2026, 9, 30), Date.new(2026, 10, 1)].each do |day|
        create(:task, :done, completed_at: at(day))
        carried(day)
        create(:post, :published, published_at: at(day))
        create(:social_post, :posted, posted_at: at(day))
        create(:journal_entry, entry_date: day, body: "a day")
        create(:commit, repo: "aaronmallen/one", commit_date: day, additions: 1, deletions: 0)
        work(at(day, 9), at(day, 10))
        close("resolved", day, chosen: "Sidekiq")
      end
    end

    it "groups the tasks done inside it" do
      expect(dates(review.fetch("done"))).to eq(inside)
    end

    it "lists the tasks carried inside it" do
      expect(review.fetch("carried").map { it.fetch("sprint_on") }.sort).to eq(inside)
    end

    it "lists the posts and social posts published inside it" do
      expect(review.values_at("posts", "social_posts").map { dates(it) }).to eq([inside, inside])
    end

    it "lists the journal entries written inside it" do
      expect(dates(review.dig("journal", "entries"))).to eq(inside)
    end

    it "totals the commits made inside it" do
      expect(review.fetch("commits").map { it.values_at("repo", "commits") }).to eq([["aaronmallen/one", 2]])
    end

    it "lists the decisions closed inside it" do
      expect(dates(review.fetch("decisions"))).to eq(inside)
    end

    it "sums the time worked inside it" do
      expect(dates(review.fetch("worked").select { it.fetch("seconds").positive? })).to eq(inside)
    end
  end

  it "keeps a Sunday in the week before the next Monday" do
    expect(read(day: "2026-09-20").values_at("from", "to")).to eq(%w[2026-09-14 2026-09-20])
  end

  it "reads the week that holds today when it names no period or day" do
    monday = today - (today.cwday - 1)

    expect(read.values_at("period", "from", "to")).to eq(["week", monday.iso8601, (monday + 6).iso8601])
  end

  it "refuses a period other than week or month with a 422" do
    expect([read(period: "year").fetch("errors").keys, status]).to eq([%w[period], 422])
  end

  it "refuses a day it cannot read with a 422" do
    refusal = { "error" => "invalid", "message" => "give the day as a date, such as 2026-01-01",
                "errors" => { "day" => ["give the day as a date, such as 2026-01-01"] } }

    expect([read(day: "2026-13-40"), status]).to eq([refusal, 422])
  end

  describe "contributors" do
    let(:agent) { { "kind" => "agent", "agent" => "claude-code", "model" => "claude-opus-5-5" } }

    before do
      fill(wednesday, title: "Mine")
      shared = create(:task, :done, title: "Shared", completed_at: at(wednesday))
      create(:task_contributor, :owner, task_id: shared.id)
      create(:task_contributor, task_id: shared.id)
      sonnet = create(:task, :done, title: "Sonnet's", completed_at: at(wednesday))
      create(:task_contributor, task_id: sonnet.id, model: "claude-sonnet-5")
    end

    def done_titles(**query)
      read(day: wednesday.iso8601, **query).fetch("done").flat_map { it.fetch("tasks") }.map { it.fetch("title") }
    end

    it "lists who did each done task, the owner when it lists no one" do
      tasks = read(day: wednesday.iso8601).fetch("done").first.fetch("tasks")

      expect(tasks.to_h { it.values_at("title", "contributors") }).to include(
        "Mine" => [{ "kind" => "owner" }], "Shared" => [{ "kind" => "owner" }, agent],
      )
    end

    it "keeps the done tasks that list the owner, the default included" do
      expect(done_titles(contributor: "owner")).to contain_exactly("Mine", "Shared")
    end

    it "keeps the done tasks an agent worked on, by agent or by model" do
      both = contain_exactly("Shared", "Sonnet's")
      found = [done_titles(contributor: "agent"), done_titles(agent: "claude-code")]

      expect([*found, done_titles(model: "claude-sonnet-5")]).to match([both, both, ["Sonnet's"]])
    end

    it "counts only the done tasks it keeps and leaves the time worked and the carried tasks whole" do
      totals = read(day: wednesday.iso8601, model: "claude-sonnet-5").fetch("totals")

      expect(totals).to include("done" => 1, "carried" => 1, "worked_seconds" => 3600)
    end

    it "reads through read_review as the endpoint does" do
      expect(mcp_answer("read_review", day: wednesday.iso8601, contributor: "agent"))
        .to eq(read(day: wednesday.iso8601, contributor: "agent"))
    end

    it "refuses a contributor that is neither the owner nor an agent with a 422" do
      expect([read(contributor: "robot").fetch("errors").keys, status]).to eq([%w[contributor], 422])
    end
  end

  describe "the MCP tool" do
    it "reads as read_review does" do
      fill(wednesday)
      close("resolved", wednesday, title: "Pick a queue", chosen: "Sidekiq")

      expect(read(period: "month", day: wednesday.iso8601))
        .to eq(mcp_answer("read_review", period: "month", day: wednesday.iso8601))
    end

    it "refuses a bad period, naming what the endpoint names" do
      refused = read(period: "year")
      answer = mcp_call("read_review", period: "year")

      text = answer.dig("content", 0, "text")

      expect([answer.fetch("isError"), text]).to match([true, end_with(refused.fetch("message"))])
    end

    it "refuses a bad day with the message the endpoint gives" do
      refused = read(day: "next week")

      expect(mcp_text("read_review", day: "next week")).to eq(refused.fetch("message"))
    end
  end
end
