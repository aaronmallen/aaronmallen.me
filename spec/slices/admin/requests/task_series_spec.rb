# frozen_string_literal: true

RSpec.describe "Admin recurring tasks", :frozen_clock, type: :request do
  let(:i18n) { Admin::Slice["i18n"] }
  let(:page) { Capybara.string(last_response.body) }
  let(:task) { create(:task, title: "Water the plants") }

  def cadence(on = task, **fields) = Tasks::Slice["operations.set_task_cadence"].call(on.id, fields).value!

  def complete(on) = Tasks::Slice["operations.complete_task"].call(on.id)

  def current(series) = Tasks::Slice["repos.task_series_queries"].by_id(series.id)

  def long(date) = i18n.l(date, format: :long)

  def recurring
    get "/admin/tasks", filter: "recurring"
    page
  end

  def rows = recurring.all(".series-row")

  def switch(series, on: false)
    post "/admin/tasks/series/#{series.id}/switch", { _csrf_token: admin_csrf_token, on: (on ? "1" : "0") }
  end

  def switched_on = have_checked_field("on")

  def today = Blog::TimeZone.today

  before { sign_in_to_admin }

  it "puts the recurring tab after external with its count" do
    cadence(cadence: "days", every: 1)

    tabs = recurring.all(".task-tabs .screen-tab").map { it.all("span").map(&:text) }
    expect(tabs[4..5]).to eq([%w[external 0], %w[recurring 1]])
  end

  it "shows each series once with its title, cadence, next date and switch" do
    series = cadence(cadence: "days", every: 3)
    complete(task)
    link = have_link("Water the plants", href: "/admin/tasks/#{current(series).task_id}")

    expect(rows).to contain_exactly(link.and(have_text("Every 3 days · next #{long(today + 3)}")).and(switched_on))
  end

  it "says an open copy outside a sprint has no date yet" do
    cadence(cadence: "month_end")

    expect(rows.first).to have_text("Last day of each month · not in a sprint")
  end

  it "gives the date a paused series would resume on" do
    series = cadence(cadence: "days", every: 2)
    switch(series)
    complete(task)

    expect(rows.first).to have_text("next #{long(today + 2)}")
  end

  {
    { cadence: "days", every: 1 } => "Every day",
    { cadence: "weeks", every: 1, weekday: 4 } => "Every Thursday",
    { cadence: "weeks", every: 2, weekday: 4 } => "Every 2 weeks on Thursday",
    { cadence: "month_day", day: 1 } => "Day 1 of each month",
    { cadence: "month_end" } => "Last day of each month",
    { cadence: "month_weekday", week: 1, weekday: 1 } => "The first Monday of each month",
    { cadence: "month_weekday", week: -1, weekday: 5 } => "The last Friday of each month",
    { cadence: "yearly", month: 3, day: 4 } => "Each year on March 4",
  }.each do |fields, text|
    it "describes #{text.downcase}" do
      cadence(**fields)

      expect(rows.first.find(".series-meta")).to have_text(text)
    end
  end

  it "says when nothing repeats" do
    expect(recurring).to have_text(i18n.t("ui.components.tasks.recurring_card.empty"))
  end

  describe "the switch" do
    it "pauses the series and keeps its cadence", :aggregate_failures do
      series = cadence(cadence: "days", every: 1)

      switch(series)

      expect(last_response.headers["Location"]).to eq("/admin/tasks?filter=recurring")
      expect(current(series)).to have_attributes(paused: true, cadence: "days", every: 1)
      expect(rows.first).to have_unchecked_field("on")
    end

    it "makes no copy when a paused series closes its copy" do
      series = cadence(cadence: "days", every: 1)
      switch(series)

      complete(task)

      expect(current(series).task_id).to eq(task.id)
    end

    it "makes the next copy at once when it resumes a series whose copy closed" do
      series = cadence(cadence: "days", every: 1)
      switch(series)
      complete(task)

      switch(series, on: true)

      expect([current(series).paused, current(series).task_id == task.id]).to eq([false, false])
    end

    it "makes nothing when it resumes a series whose copy is open" do
      series = cadence(cadence: "days", every: 1)
      switch(series)

      switch(series, on: true)

      expect(current(series)).to have_attributes(paused: false, task_id: task.id)
    end

    it "answers 404 for a series that is gone" do
      switch(Struct.new(:id).new(0))

      expect(last_response.status).to eq(404)
    end
  end
end
