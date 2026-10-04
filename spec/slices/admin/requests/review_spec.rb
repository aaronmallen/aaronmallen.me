# frozen_string_literal: true

RSpec.describe "Admin review", type: :request do
  let(:page) { Capybara.string(last_response.body) }
  let(:today) { Blog::TimeZone.today }
  let(:wednesday) { Date.new(2026, 9, 16) }

  def at(day, hour = 12) = Blog::TimeZone.local_time(day.year, day.month, day.day, hour)

  def card(name) = page.find("#review-#{name}")

  def fill(day, title: "Finish the review screen")
    done = create(:task, :done, title:, completed_at: at(day), worked_seconds: 5400)
    sprint = create(:sprint, sprint_date: day)
    carried = create(:task, list: nil, sprint_id: sprint.id, carried_count: 3, title: "Call the accountant")
    create(:work_session, task_id: done.id, started_at: at(day, 9), ended_at: at(day, 10))
    { done:, carried: }
  end

  def visit_review(params = {}) = get("/admin/review", params)

  describe "signed out" do
    it "redirects to sign-in" do
      visit_review

      expect(last_response.location).to end_with("/admin/sign-in")
    end
  end

  describe "signed in" do
    before { sign_in_to_admin }

    describe "the current week" do
      before { visit_review }

      it "says the review is where you are" do
        expect(page).to have_css(".ctx-where", text: %r{Insights\s+/\s+review})
      end

      it "lists the review in the palette with its icon" do
        expect(page).to have_css("#command-palette-review i.fa-calendar-week", visible: :all)
      end

      it "runs from Monday to Sunday" do
        monday = today - (today.cwday - 1)
        span = "#{monday.strftime('%b %-d')} → #{(monday + 6).strftime('%b %-d, %Y')}"

        expect(page).to have_css(".page-head-sub", text: span)
      end

      it "draws a row of time worked for each day of the week" do
        expect(card("worked")).to have_css(".meter-row", count: 7)
      end

      it "marks the week as the current period" do
        expect(page).to have_css(".seg-option.current[aria-current='page']", text: "Week")
      end

      it "offers no way back to a week it already shows" do
        expect(page).to have_no_link("This week")
      end

      it "renders without a missing translation" do
        expect(last_response.body).not_to include("translation_missing")
      end
    end

    describe "a week with records" do
      let!(:filled) { fill(wednesday) }

      before do
        create(:post, :published, title: "A post that went out", published_at: at(wednesday))
        create(:social_post, :posted, posted_at: at(Date.new(2026, 9, 18)))
        create(:journal_entry, entry_date: Date.new(2026, 9, 14), body: "one two three")
        create(:journal_entry, entry_date: Date.new(2026, 9, 15), body: "four five")
        create(:commit, repo: "aaronmallen/one", commit_date: wednesday, additions: 10, deletions: 2)
        visit_review(day: "2026-09-17")
      end

      it "names the week that holds the day" do
        expect(page).to have_css(".page-head-sub", text: "Sep 14 → Sep 20, 2026")
      end

      it "counts the tasks done, the tasks carried, the time worked and the commits" do
        values = page.all(".stat").map { [it.find(".stat-key").text, it.find(".stat-value").text] }

        expect(values).to eq([%w[Done 1], %w[Carried 1], ["Worked", "1h 00m"], %w[Commits 1]])
      end

      it "groups each done task under its day and links it to its task, with the time worked on it" do
        group = card("done").find(".review-group", text: "Wednesday, September 16")

        expect([group.find_link("Finish the review screen")[:href], group.find(".li-sub").text])
          .to eq(["/admin/tasks/#{filled[:done].id}", "1h 30m"])
      end

      it "links each carried task to its task and says how many days it slipped" do
        link = card("carried").find_link("Call the accountant")

        expect([link[:href], card("carried").find(".li-sub").text])
          .to eq(["/admin/tasks/#{filled[:carried].id}", "Slipped 3 days"])
      end

      it "lists the posts and social posts published" do
        groups = card("published").all(".review-group-title").map(&:text)

        expect([groups, card("published")]).to match([["Posts", "Social posts"], have_link("A post that went out")])
      end

      it "sums the journal's entries, words and streak" do
        expect(card("journal")).to have_css(".review-note", text: "2 entries · 5 words · a 2-day streak")
      end

      it "links each journal entry to its day" do
        expect(card("journal")).to have_link("one two three", href: "/admin/journal?to=2026-09-14#day-2026-09-14")
      end

      it "totals the commits by repo" do
        expect(card("commits").find(".li", text: "aaronmallen/one")).to have_text("1 commit · +10 −2")
      end

      it "gives the time worked on each day and in all" do
        row = card("worked").find(".meter-row", text: "Wed Sep 16")

        expect([row.find(".meter-count").text, card("worked").find(".review-total").text]).to eq(["1h 00m", "1h 00m"])
      end

      it "renders without a missing translation" do
        expect(last_response.body).not_to include("translation_missing")
      end
    end

    describe "the week's arrows" do
      before { visit_review(day: "2026-09-16") }

      it "step back a week" do
        expect(page).to have_link("Previous week", href: "/admin/review?day=2026-09-09")
      end

      it "step forward a week" do
        expect(page).to have_link("Next week", href: "/admin/review?day=2026-09-23")
      end

      it "offer a way back to this week" do
        expect(page).to have_link("This week", href: "/admin/review")
      end

      it "switch to the month that holds the day" do
        expect(page).to have_link("Month", href: "/admin/review?period=month&day=2026-09-16")
      end
    end

    describe "the month" do
      before do
        fill(Date.new(2026, 8, 31), title: "Done in August")
        fill(Date.new(2026, 9, 1), title: "Done on the first")
        fill(Date.new(2026, 9, 30), title: "Done on the last")
        visit_review(period: "month", day: "2026-09-16")
      end

      it "names the month" do
        expect(page).to have_css(".page-head-sub", text: "September 2026")
      end

      it "shows the tasks done across the calendar month" do
        expect(card("done").all("a.li-title").map(&:text)).to eq(["Done on the first", "Done on the last"])
      end

      it "draws a row of time worked for each day of the month" do
        expect(card("worked")).to have_css(".meter-row", count: 30)
      end

      it "marks the month as the current period" do
        expect(page).to have_css(".seg-option.current[aria-current='page']", text: "Month")
      end

      it "steps back a month" do
        expect(page).to have_link("Previous month", href: "/admin/review?period=month&day=2026-08-16")
      end

      it "steps forward a month" do
        expect(page).to have_link("Next month", href: "/admin/review?period=month&day=2026-10-16")
      end

      it "switches back to the week that holds the day" do
        expect(page).to have_link("Week", href: "/admin/review?day=2026-09-16")
      end

      it "renders without a missing translation" do
        expect(last_response.body).not_to include("translation_missing")
      end
    end

    describe "an empty period" do
      before { visit_review(day: "2001-01-03") }

      {
        "done" => "Nothing done yet", "carried" => "Nothing slipped", "published" => "Nothing went out",
        "commits" => "No commits",
      }.each do |name, text|
        it "says #{name} holds nothing" do
          expect(card(name)).to have_css(".empty", text:)
        end
      end

      it "sums an empty journal" do
        expect(card("journal")).to have_css(".review-note", text: "0 entries · 0 words · no streak")
      end
    end

    it "falls back to the current week on a period or day it cannot read" do
      visit_review(period: "year", day: "2026-13-40")

      expect(page).to have_css(".seg-option.current", text: "Week").and(have_no_link("This week"))
    end

    it "runs the same statements for a full month as for an empty one" do
      empty = counting { visit_review(period: "month", day: "2026-09-16") }.size
      (1..30).each { fill(Date.new(2026, 9, it), title: "Day #{it}") }

      expect(counting { visit_review(period: "month", day: "2026-09-16") }).to have(empty).items
    end
  end
end
