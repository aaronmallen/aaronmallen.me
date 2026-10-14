# frozen_string_literal: true

RSpec.describe "Admin task activity", type: :request do
  let(:i18n) { Admin::Slice["i18n"] }
  let(:page) { Capybara.string(last_response.body) }
  let(:task) { create(:task, :in_progress, title: "Ship the timeline") }
  let(:ten) { Time.at(Time.now.to_i - 86_400) }

  def event(kind, **columns) = create(:task_event, task_id: task.id, kind:, tag_name: nil, occurred_at: ten, **columns)

  def event_text(key, **) = i18n.t(key, scope: "ui.components.tasks.timeline_event", **)

  def events = page.all(".timeline-event-text", visible: :all).map(&:text)

  def facts = page.all(".task-fact").to_h { [it.find("dt").text, it.find("dd").text] }

  def read(record = task) = get("/admin/tasks/#{record.id}", filter: "next")

  def sessions = page.all(".task-session")

  def t(key, **) = i18n.t(key, scope: "ui.components.tasks.timeline", **)

  def tag(tags)
    fields = { title: task.title, tags: }

    post "/admin/tasks/#{task.id}", { _csrf_token: admin_csrf_token, filter: "next", task: fields }
  end

  def timeline = page.find("[data-task-read] details.task-timeline:not([open]) > summary")

  def worked(key, **) = i18n.t(key, scope: "ui.components.tasks.time_worked", **)

  before { sign_in_to_admin }

  it "puts the events in a closed Timeline block that counts them", :aggregate_failures do
    event("moved", from_list: "next", to_list: "someday")
    event("tagged", tag_name: "money")
    read

    expect(timeline).to have_text(t("title"))
    expect(timeline).to have_css(".task-timeline-count", exact_text: t("count", count: 2))
  end

  it "says when nothing has happened" do
    read

    expect(page).to have_css(".task-timeline .hint", visible: :all, text: t("empty"))
  end

  it "keeps comments and sessions out of the Timeline block", :aggregate_failures do
    create(:task_comment, task_id: task.id, body: "Noon")
    create(:work_session, :closed, task_id: task.id)
    read

    expect(timeline).to have_css(".task-timeline-count", exact_text: t("count", count: 0))
    expect([page.all(".task-comments .comment").size, sessions.size]).to eq([1, 1])
  end

  it "lists each session with its date, start, end and length" do
    started = Blog::TimeZone.local_time(2026, 10, 3, 9, 0)
    session = create(:work_session, :closed, task_id: task.id, started_at: started, ended_at: started + 5400)
    read

    parts = %w[span length].map { page.find("#task-session-#{session.id} .task-session-#{it}").text }

    expect(parts).to eq(["Oct 3 · 09:00–10:30", "1h 30m"])
  end

  it "shows a running session as running", :aggregate_failures do
    create(:work_session, task_id: task.id, started_at: ten)
    read

    expect(sessions.first).to have_text("–#{worked('now')}")
    expect(sessions.first).to have_css(".pill", text: worked("running"))
  end

  it "says when there are no sessions" do
    read

    expect(page).to have_css(".field .hint", text: worked("empty"))
  end

  it "shows a move between lists" do
    event("moved", from_list: "next", to_list: "someday")
    read

    expect(events).to include(event_text("moved", from: "next", to: "someday"))
  end

  it "shows a move into a sprint" do
    event("moved", from_list: "next", to_sprint_on: Date.new(2026, 10, 3))
    read

    expect(events).to include(event_text("moved", from: "next", to: "the Oct 3, 2026 sprint"))
  end

  it "shows a move out of a sprint" do
    event("moved", from_sprint_on: Date.new(2026, 10, 3), to_list: "someday")
    read

    expect(events).to include(event_text("moved", from: "the Oct 3, 2026 sprint", to: "someday"))
  end

  it "shows that a recurring series made the task" do
    event("recurred")
    read

    expect(events).to include(event_text("recurred"))
  end

  it "shows a tag added and a tag removed" do
    event("tagged", tag_name: "money")
    event("untagged", tag_name: "house")
    read

    expect(events).to include(event_text("tagged", tag: "money"), event_text("untagged", tag: "house"))
  end

  it "shows a status change" do
    event("status_changed", from_status: "open", to_status: "in_progress")
    read

    expect(events).to include(event_text("status_changed", from: "open", to: "in progress"))
  end

  it "records a real tag change on the timeline" do
    tag("garden")
    read

    expect(events).to include(event_text("tagged", tag: "garden"))
  end

  it "leaves out another task's history" do
    create(:task_event, kind: "tagged", tag_name: "elsewhere")
    read

    expect(page).to have_no_css(".timeline-event", visible: :all)
  end

  it "shows the task's total time in the facts" do
    read(create(:task, worked_seconds: 5_700))

    expect(facts).to include(i18n.t("ui.components.tasks.facts.worked") => "1h 35m")
  end
end
