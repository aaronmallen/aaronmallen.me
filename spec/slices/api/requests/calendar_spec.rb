# frozen_string_literal: true

RSpec.describe "API calendar", type: :request do
  let(:first) { Date.new(2026, 7, 13) }
  let(:last) { Date.new(2026, 7, 19) }
  let(:range) { { from: first.iso8601, to: last.iso8601 } }

  def api_token = @api_token ||= API::Slice["operations.mint_token"].call(name: "Terminal").value!.fetch(:value)

  def at(date, hour, minute = 0) = Blog::TimeZone.local_time(date.year, date.month, date.day, hour, minute)

  def day(date, **) = days(**).find { it.fetch("date") == date.iso8601 }

  def days(**params) = read(**range, **params).fetch("days")

  def listed_items
    days.to_h do |found|
      ids = found.fetch("posts").map { "post-#{it.fetch('id')}" } +
            found.fetch("social_posts").map { "social-#{it.fetch('id')}" }
      [Date.parse(found.fetch("date")), ids]
    end
  end

  def read(**params)
    headers = { "HTTP_ACCEPT" => "application/json", "HTTP_AUTHORIZATION" => "Bearer #{api_token}" }
    get "/api/v1/calendar", params, headers
    JSON.parse(last_response.body)
  end

  def screen_items(date)
    sign_in_to_admin
    get "/admin/calendar", day: date.iso8601
    items = Capybara.string(last_response.body).all("[data-calendar-item]").map { it["data-calendar-item"] }

    items.grep(/\A(post|social)-/)
  end

  def status = last_response.status

  it "answers the range and every day in it, empty days included, oldest first" do
    found = read(**range)

    expect([found.values_at("from", "to"), found.fetch("days").map { it.fetch("date") }])
      .to eq([[first.iso8601, last.iso8601], (first..last).map(&:iso8601)])
  end

  it "leaves an empty day with no sprint, posts, social posts or journal" do
    expect(day(first)).to eq(
      "date" => first.iso8601, "sprint" => nil, "posts" => [], "social_posts" => [], "journal" => false,
    )
  end

  it "gives a day its sprint and the count of tasks in it" do
    sprint = create(:sprint, sprint_date: first + 1)
    2.times { create(:task, :in_sprint, sprint_id: sprint.id) }

    expect(day(first + 1).fetch("sprint")).to eq("id" => sprint.id, "task_count" => 2)
  end

  it "lists a day's posts with their status and publish time" do
    post = create(:post, :scheduled, title: "Calendar post", published_at: at(first + 2, 9))

    expect(day(first + 2).fetch("posts").map { it.values_at("id", "title", "status", "published_at") })
      .to eq([[post.id, "Calendar post", "scheduled", post.published_at.utc.iso8601]])
  end

  it "lists a day's social posts with their status, send time and parts" do
    social_post = create(:social_post, :scheduled, posted_at: at(first + 3, 10))

    expect(day(first + 3).fetch("social_posts").map { it.values_at("id", "status", "posted_at", "parts") })
      .to eq([[social_post.id, "scheduled", social_post.posted_at.utc.iso8601, social_post.parts.map(&:body)]])
  end

  it "marks a day with a journal entry" do
    create(:journal_entry, entry_date: first + 4)

    expect(days.map { it.fetch("journal") }).to eq((first..last).map { it == first + 4 })
  end

  describe "beside the calendar screen" do
    before do
      create(:post, :published, published_at: at(first + 1, 8))
      create(:post, :scheduled, published_at: at(first + 1, 17))
      create(:post, :draft, published_at: at(first + 1, 12))
      create(:social_post, :posted, posted_at: at(first + 1, 9))
      create(:social_post, :scheduled, posted_at: at(first + 5, 23, 30))
    end

    it "lists the same posts and social posts per day" do
      expect(listed_items).to eq((first..last).to_h { [it, screen_items(it)] })
    end
  end

  it "takes a range of 366 days" do
    expect(days(to: (first + 365).iso8601).length).to eq(366)
  end

  it "refuses a range over 366 days" do
    found = read(from: first.iso8601, to: (first + 366).iso8601)

    expect([status, found.fetch("errors")]).to eq(
      [422, { "from" => [Blog::DayWindow::TOO_LONG], "to" => [Blog::DayWindow::TOO_LONG] }],
    )
  end

  it "refuses a range that ends before it starts" do
    found = read(from: first.iso8601, to: (first - 1).iso8601)

    expect([status, found.dig("errors", "from")]).to eq([422, ["from comes after to"]])
  end

  it "refuses a day it cannot read" do
    read(from: "July", to: last.iso8601)

    expect(status).to eq(422)
  end

  it "refuses a request with no range" do
    found = read

    expect([status, found.fetch("errors").keys]).to eq([422, %w[from to]])
  end

  it "answers the MCP tool with the same JSON" do
    create(:sprint, sprint_date: first)
    create(:post, :published, published_at: at(first + 2, 9))
    create(:social_post, :posted, posted_at: at(first + 3, 8))
    create(:journal_entry, entry_date: first + 4)

    expect(mcp_answer("list_calendar", **range)).to eq(read(**range))
  end

  it "answers the MCP tool with an error for a range over 366 days" do
    expect(mcp_call("list_calendar", from: first.iso8601, to: (first + 366).iso8601).fetch("isError")).to be(true)
  end
end
