# frozen_string_literal: true

RSpec.describe "Admin calendar drag", type: :feature do
  let(:day) { (today + 2).month == today.month ? today + 1 : Date.new(today.year, today.month).next_month }
  let(:target) { day + 1 }

  def at(date, hour) = Blog::TimeZone.local_time(date.year, date.month, date.day, hour)

  def box(element)
    evaluate_script(<<~JS, element)
      (r => ({ x: r.left + r.width / 2, y: r.top + r.height / 2 }))(arguments[0].getBoundingClientRect())
    JS
  end

  def cell(date) = find("a[data-calendar-day='#{date.iso8601}']")

  def drag(title, onto)
    from = box(grip(title))
    mouse = page.driver.browser.mouse

    mouse.move(x: from["x"], y: from["y"]).down
    stroke(from, box(onto)).each { mouse.move(**it) }
    mouse.up
  end

  def grip(title) = panel.find(".li", text: title).find("[data-calendar-grip]")

  def open_day(date)
    visit "/admin/calendar?day=#{date.iso8601}"
    execute_script("window.calendarLoaded = true")
  end

  def panel = find("[data-calendar-panel]")

  def sprint_on(task)
    Tasks::Slice["repos.sprint_repo"].by_id(stored_task(task).sprint_id).sprint_date
  end

  def stored_post(record) = Posts::Slice["repos.post_queries"].by_id(record.id)

  def stored_task(record) = Tasks::Slice["repos.task_repo"].by_id(record.id)

  def stroke(from, to)
    (1..6).map do |step|
      { x: from["x"] + ((to["x"] - from["x"]) * step / 6), y: from["y"] + ((to["y"] - from["y"]) * step / 6) }
    end
  end

  def touch(type, point)
    page.driver.browser.page.command("Input.dispatchTouchEvent", type:, touchPoints: point ? [point] : [])
  end

  def touch_cancel(title, onto)
    from = box(grip(title))

    touch("touchStart", { x: from["x"], y: from["y"] })
    stroke(from, box(onto)).each { touch("touchMove", it) }
    touch("touchCancel", nil)
  end

  def translate(key, **) = Admin::Slice["i18n"].t(key, **)

  before { sign_in_to_admin }

  describe "a scheduled post" do
    let!(:scheduled) { create(:post, :scheduled, title: "Spread me out", published_at: at(day, 9)) }

    before do
      open_day(day)
      drag("Spread me out", cell(target))
    end

    it "moves to the day it lands on", :aggregate_failures do
      expect(panel).to have_no_text("Spread me out")
      expect(stored_post(scheduled).published_at).to eq(at(target, 9))
    end

    it "redraws both days without loading the page", :aggregate_failures do
      expect(cell(target)).to have_css(".cal-mark.post", text: "Spread me out")
      expect(cell(day)).to have_no_css(".cal-mark.post")
      expect(evaluate_script("window.calendarLoaded")).to be(true)
    end

    it "says where it went" do
      expect(page).to have_css(".toast:not(.toast-failed)", text: "Moved to #{target.strftime('%b %-d, %Y')}")
    end
  end

  describe "a scheduled social post" do
    let!(:queued) { create(:social_post, :scheduled, posted_at: at(day, 16)) }

    before do
      open_day(day)
      drag(queued.parts.first.body[0, 20], cell(target))
    end

    it "moves to the day it lands on", :aggregate_failures do
      expect(cell(target)).to have_css(".cal-mark.social")
      expect(Social::Slice["repos.social_post_queries"].by_id(queued.id).posted_at).to eq(at(target, 16))
    end
  end

  describe "an open sprint task" do
    let!(:task) do
      create(:task, :in_sprint, sprint_id: create(:sprint, sprint_date: day).id, title: "Lighten the day")
    end

    before do
      open_day(day)
      drag("Lighten the day", cell(target))
    end

    it "moves to the sprint on the day it lands on", :aggregate_failures do
      expect(cell(target)).to have_css(".cal-mark.sprint")
      expect(sprint_on(task)).to eq(target)
    end
  end

  describe "a drag the browser cancels" do
    let!(:scheduled) { create(:post, :scheduled, title: "Stay scheduled", published_at: at(day, 9)) }

    before do
      open_day(day)
      touch_cancel("Stay scheduled", cell(target))
    end

    it "leaves the post on its day", :aggregate_failures do
      expect(page).to have_no_css(".cal-ghost, .cal-dragging, .cal-target")
      expect(panel).to have_text("Stay scheduled")
      expect(stored_post(scheduled).published_at).to eq(at(day, 9))
    end
  end

  describe "a record the day panel cannot move" do
    before do
      create(:post, :published, title: "Out already", published_at: at(today, 0))
      create(:social_post, :posted, posted_at: at(today, 0))
      create(:task, :in_sprint, :done, sprint_id: create(:sprint, sprint_date: today).id, title: "Done already")
      open_day(today)
    end

    it "has no grip", :aggregate_failures do
      expect(panel).to have_text("Done already")
      expect(panel).to have_no_css("[data-calendar-grip]", visible: :all)
    end
  end

  describe "a drop on a past day" do
    let(:past) { Date.new(2026, 7, 14) }
    let!(:task) do
      create(:task, :in_sprint, sprint_id: create(:sprint, sprint_date: past).id, title: "Stay put")
    end

    before { open_day(past) }

    it "is refused and leaves the task on its day", :aggregate_failures do
      drag("Stay put", cell(past + 1))

      expect(page).to have_css(".toast-failed", text: translate("calendar_page.toasts.past"))
      expect(panel).to have_text("Stay put")
      expect(sprint_on(task)).to eq(past)
    end
  end

  describe "a save that fails" do
    let!(:scheduled) { create(:post, :scheduled, title: "Hold still", published_at: at(day, 9)) }

    before { open_day(day) }

    it "says it failed and leaves the post where it was", :aggregate_failures do
      Posts::Slice["repos.post_mutations"].delete(scheduled.id)
      drag("Hold still", cell(target))

      expect(page).to have_css(".toast-failed", text: translate("ui.components.calendar.panel.failed"))
      expect(panel).to have_text("Hold still")
      expect(cell(day)).to have_css(".cal-mark.post", text: "Hold still")
    end

    it "shows the refusal when the post went out first", :aggregate_failures do
      Posts::Slice["repos.post_mutations"].update(scheduled.id, status: "published")
      drag("Hold still", cell(target))

      expect(page).to have_css(".toast-failed", text: translate("calendar_page.toasts.not_scheduled"))
      expect(panel).to have_text("Hold still")
    end
  end
end
