# frozen_string_literal: true

RSpec.describe "API review", type: :request do
  let(:wednesday) { Date.new(2026, 9, 16) }

  def api_token = @api_token ||= API::Slice["operations.mint_token"].call(name: "Terminal").value!.fetch(:value)

  def at(day, hour = 12) = Blog::TimeZone.local_time(day.year, day.month, day.day, hour)

  def carry(task, from)
    create(:task_event, :carried, task_id: task.id, from_sprint_on: from, to_sprint_on: from + 1,
                                  occurred_at: at(from + 1))
  end

  def close(kind, day, title:, chosen: nil)
    decision = create(:decision, title:)
    option_id = chosen && create(:decision_option, decision_id: decision.id, title: chosen).id
    create(:decision_event, decision_id: decision.id, kind:, option_id:, reason: "Settled", created_at: at(day))
    decision
  end

  def fill(day, title: "Finish the review screen")
    done = create(:task, :done, title:, completed_at: at(day), worked_seconds: 5400)
    carried = create(:task, :in_sprint)
    [day - 2, day - 1, day].each { carry(carried, it) }
    create(:work_session, task_id: done.id, started_at: at(day, 9), ended_at: at(day, 10))
    { done:, carried: }
  end

  def read(**query)
    headers = { "HTTP_ACCEPT" => "application/json", "HTTP_AUTHORIZATION" => "Bearer #{api_token}" }
    get "/api/v1/review", query, headers
    JSON.parse(last_response.body)
  end

  def stats
    sign_in_to_admin
    get "/admin/review", day: wednesday.iso8601
    Capybara.string(last_response.body).all(".stat-value").map(&:text)
  end

  def status = last_response.status

  def today = Blog::TimeZone.today

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
      task = { "id" => filled[:done].id, "title" => "Finish the review screen", "worked_seconds" => 5400 }

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
      worked = Blog::Figures.hours(totals.fetch("worked_seconds"))
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
