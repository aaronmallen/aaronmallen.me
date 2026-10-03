# frozen_string_literal: true

RSpec.describe "Admin calendar", type: :request do
  let(:page) { Capybara.string(last_response.body) }
  let(:today) { Blog::TimeZone.today }
  let(:day) { Date.new(2026, 7, 14) }

  def at(date, hour = 12) = Blog::TimeZone.local_time(date.year, date.month, date.day, hour)

  def cell(date) = page.find(".cal-day:has(time[datetime='#{date.iso8601}'])")

  def fill_day
    create(:journal_entry, entry_date: day)
    create(:social_post, :posted, posted_at: at(day, 8))

    {
      task: plan_sprint,
      post: create(:post, :scheduled, title: "A post on its day", published_at: at(day, 9)),
      queued: create(:social_post, :scheduled, posted_at: at(day, 10)),
    }
  end

  def panel = page.find("[data-calendar-panel]")

  def plan_sprint
    sprint = create(:sprint, sprint_date: day)
    create(:task, :in_sprint, sprint_id: sprint.id)
    create(:task, :in_sprint, sprint_id: sprint.id, title: "Write the calendar")
  end

  def visit_calendar(params = {}) = get("/admin/calendar", params)

  describe "signed out" do
    it "redirects to sign-in" do
      visit_calendar

      expect(last_response.location).to end_with("/admin/sign-in")
    end
  end

  describe "signed in" do
    before { sign_in_to_admin }

    describe "the current month" do
      before { visit_calendar }

      it "says the calendar is where you are" do
        expect(page).to have_css(".ctx-where", text: %r{Daily\s+/\s+calendar})
      end

      it "lists the calendar in the palette with its icon" do
        expect(page).to have_css("#command-palette-calendar i.fa-calendar-days", visible: :all)
      end

      it "names the month in the heading" do
        expect(page).to have_css(".page-head-sub", text: today.strftime("%B %Y"))
      end

      it "marks today, and only today" do
        expect(page.all("[aria-current='date']").map { it.find("time")[:datetime] }).to eq([today.iso8601])
      end

      it "opens today's panel" do
        expect(panel["data-calendar-panel"]).to eq(today.iso8601)
      end

      it "draws whole weeks from Monday that hold every day of the month" do
        dates = page.all(".cal-day time").map { Date.iso8601(it[:datetime]) }
        first = Date.new(today.year, today.month)

        expect([dates.first.cwday, dates.last.cwday, dates.size % 7, dates]).to match(
          [1, 7, 0, include(*(first..(first.next_month - 1)).to_a)],
        )
      end
    end

    describe "a day in the month" do
      before do
        fill_day
        visit_calendar(month: "2026-07")
      end

      it "shows its sprint and task count, its posts, its social posts and the journal mark" do
        marks = cell(day).all(".cal-mark").map { [it[:class].split.last, it.text] }

        expect(marks).to eq(
          [["sprint", "2 tasks"], ["post", "A post on its day"], ["social", "2 social posts"], %w[journal journal]],
        )
      end

      it "leaves an empty day bare" do
        expect(cell(day + 1)).to have_no_css(".cal-mark")
      end

      it "links the day to its panel" do
        expect(cell(day).find("a.cal-link")[:href]).to eq("/admin/calendar?day=2026-07-14")
      end
    end

    describe "a day's panel" do
      let!(:filled) { fill_day }

      before { visit_calendar(day: "2026-07-14") }

      it "opens on that day's month" do
        expect(page).to have_css(".page-head-sub", text: "July 2026")
      end

      it "marks the day as picked" do
        expect(page.all(".cal-picked time").map { it[:datetime] }).to eq(%w[2026-07-14])
      end

      it "names the day" do
        expect(panel).to have_css(".card-title", text: "Tuesday, July 14, 2026")
      end

      it "links each sprint task" do
        expect(panel).to have_link("Write the calendar", href: "/admin/tasks/#{filled[:task].id}")
      end

      it "links each post to its editor" do
        expect(panel).to have_link("A post on its day", href: "/admin/posts/#{filled[:post].id}/edit")
      end

      it "says when each post and social post goes out" do
        times = panel.all(".li-sub", text: /·/).map(&:text)

        expect(times).to eq(["scheduled · 09:00", "posted · 08:00", "scheduled · 10:00"])
      end

      it "links a queued social post to its editor and a sent one to the posted queue" do
        hrefs = panel.find(".cal-group", text: "Social posts").all("a.li-title").map { it[:href] }

        expect(hrefs).to eq(["/admin/social?filter=posted", "/admin/social?filter=queued&edit=#{filled[:queued].id}"])
      end

      it "links the journal for that day" do
        expect(panel).to have_link("Journal entry", href: "/admin/journal?to=2026-07-14")
      end
    end

    it "says when a day holds nothing" do
      visit_calendar(day: "2026-07-15")

      expect(panel).to have_css(".empty", text: "Nothing lands on this day")
    end

    it "says when a sprint holds no tasks" do
      create(:sprint, sprint_date: day)
      visit_calendar(day: day.iso8601)

      expect(panel).to have_css(".cal-group", text: /Sprint · 0 tasks\s*No tasks in this sprint yet/)
    end

    describe "the arrows" do
      before { visit_calendar(month: "2026-01") }

      it "step back to the month before" do
        expect(page).to have_link("Previous month, December 2025", href: "/admin/calendar?month=2025-12")
      end

      it "step forward to the month after" do
        expect(page).to have_link("Next month, February 2026", href: "/admin/calendar?month=2026-02")
      end

      it "offer a way back to this month" do
        expect(page).to have_link("This month", href: "/admin/calendar")
      end
    end

    it "opens the first of a month that holds no today" do
      visit_calendar(month: "2026-02")

      expect(panel["data-calendar-panel"]).to eq("2026-02-01")
    end

    it "falls back to this month on a month it cannot read" do
      visit_calendar(month: "2026-13")

      expect(page).to have_css(".page-head-sub", text: today.strftime("%B %Y"))
    end
  end
end
