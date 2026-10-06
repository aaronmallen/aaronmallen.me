# frozen_string_literal: true

RSpec.describe "Admin task activity", type: :request do
  let(:i18n) { Admin::Slice["i18n"] }
  let(:page) { Capybara.string(last_response.body) }
  let(:task) { create(:task, :in_progress, title: "Ship the timeline") }
  let(:ten) { Time.at(Time.now.to_i - 86_400) }

  def entries = page.all(".timeline > li")

  def event(kind, **columns) = create(:task_event, task_id: task.id, kind:, tag_name: nil, occurred_at: ten, **columns)

  def event_text(key, **) = i18n.t(key, scope: "ui.components.tasks.timeline_event", **)

  def facts = page.all(".task-fact").to_h { [it.find("dt").text, it.find("dd").text] }

  def read(record = task) = get("/admin/tasks/#{record.id}", filter: "next")

  def t(key, **) = i18n.t(key, scope: "ui.components.tasks.timeline", **)

  def tag(tags)
    fields = { title: task.title, tags: }

    post "/admin/tasks/#{task.id}", { _csrf_token: admin_csrf_token, filter: "next", task: fields }
  end

  before { sign_in_to_admin }

  it "names the section Activity inside the part the flyout reads", :aggregate_failures do
    read

    expect(page).to have_css("[data-task-read] .timeline-card .card-title", exact_text: t("title"))
    expect(page).to have_no_text("Talk")
  end

  it "says when nothing has happened" do
    read

    expect(page).to have_css(".timeline-card .hint", text: t("empty"))
  end

  it "puts comments and sessions in time order" do
    create(:task_comment, task_id: task.id, body: "Noon", created_at: ten + 7200)
    create(:work_session, :closed, task_id: task.id, started_at: ten + 3600, ended_at: ten + 5400)
    create(:task_comment, task_id: task.id, body: "Ten", created_at: ten)
    read

    expect(entries.map(&:text)).to match([/Ten/, /#{event_text('worked', span: '30m')}/, /Noon/])
  end

  it "shows a running session as running" do
    create(:work_session, task_id: task.id, started_at: ten)
    read

    expect(page).to have_css(".timeline-event[data-task-event='session'] .pill", text: event_text("running_pill"))
  end

  it "shows a move between lists" do
    event("moved", from_list: "next", to_list: "someday")
    read

    expect(page).to have_css(".timeline-event", text: event_text("moved", from: "next", to: "someday"))
  end

  it "shows a move into a sprint" do
    event("moved", from_list: "next", to_sprint_on: Date.new(2026, 10, 3))
    read

    expect(page).to have_css(".timeline-event", text: event_text("moved", from: "next", to: "the Oct 3, 2026 sprint"))
  end

  it "shows a move out of a sprint" do
    event("moved", from_sprint_on: Date.new(2026, 10, 3), to_list: "someday")
    read

    expect(page)
      .to have_css(".timeline-event", text: event_text("moved", from: "the Oct 3, 2026 sprint", to: "someday"))
  end

  it "shows a tag added and a tag removed", :aggregate_failures do
    event("tagged", tag_name: "money")
    event("untagged", tag_name: "house")
    read

    expect(page).to have_css(".timeline-event", text: event_text("tagged", tag: "money"))
    expect(page).to have_css(".timeline-event", text: event_text("untagged", tag: "house"))
  end

  it "shows a status change" do
    event("status_changed", from_status: "open", to_status: "in_progress")
    read

    expect(page).to have_css(".timeline-event", text: event_text("status_changed", from: "open", to: "in progress"))
  end

  it "records a real tag change on the timeline" do
    tag("garden")
    read

    expect(page).to have_css(".timeline-event", text: event_text("tagged", tag: "garden"))
  end

  it "leaves out another task's history" do
    create(:task_event, kind: "tagged", tag_name: "elsewhere")
    read

    expect(page).to have_no_css(".timeline-event")
  end

  it "shows the task's total time in the facts" do
    read(create(:task, worked_seconds: 5_700))

    expect(facts).to include(i18n.t("ui.views.tasks.show.worked") => "1h 35m")
  end
end
