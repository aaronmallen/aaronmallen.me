# frozen_string_literal: true

RSpec.describe "Admin review", :frozen_clock, type: :request do
  let(:page) { Capybara.string(last_response.body) }
  let(:today) { Blog::TimeZone.today }
  let(:wednesday) { Date.new(2026, 9, 16) }

  def at(day, hour = 12) = Blog::TimeZone.local_time(day.year, day.month, day.day, hour)

  def card(name) = page.find("#review-#{name}")

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
    carried = create(:task, :in_sprint, title: "Call the accountant")
    [day - 2, day - 1, day].each { carry(carried, it) }
    create(:work_session, task_id: done.id, started_at: at(day, 9), ended_at: at(day, 10))
    decision = close("resolved", day, title: "Pick a queue for #{title}", chosen: "Sidekiq")
    { done:, carried:, decision: }
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
        expect(page).to have_css(".screen-tab[aria-current='page']", text: "review")
      end

      it "lists the review in the palette with its icon" do
        expect(page).to have_css("#command-palette-review i.fa-magnifying-glass-chart", visible: :all)
      end

      it "runs from Monday to Sunday" do
        monday = today - (today.cwday - 1)
        span = "#{monday.strftime('%b %-d')} → #{(monday + 6).strftime('%b %-d, %Y')}"

        expect(page).to have_css(".page-head-sub", text: span)
      end

      it "lays the cards out in columns" do
        expect(page.all(".g-main > .cols > .card").map { it[:id] }).to eq(
          %w[review-done review-carried review-decisions review-journal review-published review-commits review-worked],
        )
      end

      it "keeps the note beside the cards" do
        expect(page).to have_css(".g-main > #review-notes.review-notes")
      end

      it "says no time was logged" do
        expect(card("worked")).to have_css(".empty", text: "No time logged")
      end

      it "marks the week as the current period" do
        expect(page).to have_css(".seg-option.current[aria-current='page']", text: "Week")
      end

      it "offers no way back to a week it already shows" do
        expect(page).to have_no_link("This week")
      end
    end

    describe "a week with records" do
      let!(:filled) { fill(wednesday) }
      let!(:dropped) { close("dropped", Date.new(2026, 9, 18), title: "Move to a VPS") }

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
        expect(page.find(".page-head-sub").text)
          .to eq("Sep 14 → Sep 20, 2026: 1 done, 1 carried, 1h 30m worked, 1 commit")
      end

      it "titles each card with its count" do
        titles = page.all(".g-main > .cols .card-title").map(&:text)

        expect(titles).to eq(
          ["Done · 1", "Carried over · 1", "Decisions · 2", "Journal", "Published · 2", "Commits · 1", "Time worked"],
        )
      end

      it "links each carried task to its task and says how many days it slipped" do
        item = card("carried").find(".li", text: "Call the accountant")

        expect([item.find_link("Call the accountant")[:href], item.find(".review-slipped").text])
          .to eq(["/admin/tasks/#{filled[:carried].id}", "Slipped 3 days"])
      end

      it "groups the posts apart from each network the social posts went to" do
        names = card("published").all(".review-group-name").map(&:text)

        expect([names, card("published")]).to match([%w[Posts Bluesky Mastodon], have_link("A post that went out")])
      end

      it "opens Posts and Social from their groups" do
        heads = card("published").all("a.review-group-head").map { it[:href] }

        expect(heads).to eq(%w[/admin/posts /admin/social?filter=posted /admin/social?filter=posted])
      end

      it "sums the journal's entries, words and days written" do
        expect(card("journal").find(".review-stat").text).to eq("2 entries · 5 words · 2 days written")
      end

      it "links the journal" do
        expect(card("journal")).to have_link("Open journal →", href: "/admin/journal")
      end

      it "totals the commits by repo" do
        expect(card("commits").find(".review-bar", text: "one")).to have_text("1 commit · +10 −2")
      end

      it "links each resolved decision to its decision and names the option chosen" do
        item = card("decisions").find(".li", text: "Pick a queue")
        href = item.find_link("Pick a queue for Finish the review screen")[:href]

        expect([href, item.find(".li-side").text]).to eq(["/admin/decisions/#{filled[:decision].id}", "Chose Sidekiq"])
      end

      it "links each dropped decision to its decision and says it was dropped" do
        item = card("decisions").find(".li", text: "Move to a VPS")

        expect([item.find_link("Move to a VPS")[:href], item.find(".li-side").text])
          .to eq(["/admin/decisions/#{dropped.id}", "Dropped"])
      end

      it "gives the time worked in all, its average and the days worked" do
        expect(card("worked").find(".review-stat").text).to eq("1h 30m 1h 30m avg · 1 day worked")
      end

      it "lists only the days with time on them, longest first" do
        expect(card("worked").all(".review-bar-name").map(&:text)).to eq(["Wed Sep 16"])
      end
    end

    describe "done tasks" do
      def done_groups = card("done").all(".review-group-name").map(&:text)

      def link(task, project)
        Links::Slice["operations.link_records"].call("task", task.id, { other_kind: "project", other_id: project.id })
      end

      before do
        site = create(:project, name: "aaronmallen.me")
        link(create(:task, :done, title: "Fix the feed", tags: %w[site bug], completed_at: at(wednesday)), site)
        link(create(:task, :done, title: "Fix the nav", tags: %w[site], completed_at: at(wednesday)), site)
        create(:task, :done, title: "Fix the stove", completed_at: at(Date.new(2026, 9, 17)))
      end

      it "groups them by tag, the largest first, and counts a task in each of its tags" do
        visit_review(day: "2026-09-16")

        expect(done_groups).to eq(%w[#site #bug untagged])
      end

      it "notes that a task with two tags counts in both" do
        visit_review(day: "2026-09-16")

        expect(card("done")).to have_css(".review-foot .hint", text: "two tags count in both")
      end

      it "opens Tasks › Completed for the period from the card" do
        visit_review(day: "2026-09-16")

        expect(card("done"))
          .to have_link("All 3 in Tasks →", href: "/admin/tasks?filter=completed&from=2026-09-14&to=2026-09-20")
      end

      it "adds the tag to the tasks search from its group" do
        visit_review(day: "2026-09-16")

        expect(card("done").find("a.review-group-head", text: "#site")[:href])
          .to eq("/admin/tasks?filter=completed&from=2026-09-14&to=2026-09-20&q=tag:site")
      end

      it "previews two tasks of a group" do
        visit_review(day: "2026-09-16")

        expect(card("done").find(".review-group", text: "#site").all(".review-line").map(&:text))
          .to eq(["Fix the feed", "Fix the nav"])
      end

      it "groups them by project" do
        visit_review(day: "2026-09-16", group: "project")

        expect(done_groups).to eq(["aaronmallen.me", "no project"])
      end

      it "adds the project's slug to the tasks search from its group" do
        visit_review(day: "2026-09-16", group: "project")

        expect(card("done").find("a.review-group-head", text: "aaronmallen.me")[:href])
          .to end_with("&q=project:aaronmallen-me")
      end

      it "drops the note on two tags when grouped by project" do
        visit_review(day: "2026-09-16", group: "project")

        expect(card("done")).to have_no_css(".hint", text: "two tags")
      end

      it "switches the grouping and keeps the period", :aggregate_failures do
        visit_review(day: "2026-09-16")

        expect(card("done")).to have_link("by project", href: "/admin/review?day=2026-09-16&group=project")
        expect(card("done")).to have_css(".seg-option.current", text: "by tag")
      end

      it "keeps the grouping on the arrows" do
        visit_review(day: "2026-09-16", group: "project")

        expect(page).to have_link("Previous week", href: "/admin/review?day=2026-09-09&group=project")
      end
    end

    describe "caps" do
      before do
        7.times do |n|
          create(:task, :done, title: "Task #{n}", tags: ["tag-#{n}"], completed_at: at(wednesday))
          create(:commit, repo: "aaronmallen/repo-#{n}", commit_date: wednesday)
          carry(create(:task, :in_sprint, title: "Carried #{n}"), wednesday)
        end
        visit_review(day: "2026-09-16")
      end

      it "shows five groups and folds the rest behind a toggle" do
        summary = card("done").find(".review-more summary")

        expect([summary.find(".review-more-show").text, summary.find(".review-more-hide").text])
          .to eq(["Show 2 more", "Show fewer"])
      end

      it "keeps the groups past five inside the toggle" do
        expect([card("done").all(".review-group", visible: :all).size,
                card("done").all(".review-more .review-group", visible: :all).size])
          .to eq([7, 2])
      end

      it "folds the commits past five behind a toggle" do
        expect(card("commits").all(".review-more .review-bar", visible: :all).size).to eq(2)
      end

      it "shows five carried tasks and links the rest to Tasks › Today", :aggregate_failures do
        expect(card("carried").all(".li").size).to eq(5)
        expect(card("carried")).to have_link("All 7 →", href: "/admin/tasks")
      end
    end

    describe "a group past two items" do
      before do
        4.times { create(:task, :done, title: "Site #{it}", tags: %w[site], completed_at: at(wednesday)) }
        create(:journal_entry, entry_date: wednesday, body: "walked\nfar", tags: %w[health])
        visit_review(day: "2026-09-16")
      end

      it "previews two items and counts the rest" do
        group = card("done").find(".review-group", text: "#site")

        expect([group.all(".review-line").size, group.find(".review-top > .meta").text]).to eq([2, "+2 more"])
      end

      it "groups the journal by tag and links each entry to its day by its first line" do
        expect(card("journal").find(".review-group", text: "#health"))
          .to have_link("Sep 16 walked", href: "/admin/journal?to=2026-09-16#day-2026-09-16")
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

    describe "contributors" do
      def done_titles = card("done").all(".review-line").map(&:text).uniq

      before do
        fill(wednesday, title: "Mine")
        shared = create(:task, :done, title: "Shared", completed_at: at(wednesday))
        create(:task_contributor, :owner, task_id: shared.id)
        create(:task_contributor, task_id: shared.id)
        sonnet = create(:task, :done, title: "Sonnet's", completed_at: at(wednesday))
        create(:task_contributor, task_id: sonnet.id, model: "claude-sonnet-5")
      end

      it "keeps the done tasks that list me, the default included, and counts only those" do
        visit_review(day: "2026-09-16", contributor: "owner")

        expect([done_titles, page.find(".page-head-sub").text])
          .to match([contain_exactly("Mine", "Shared"), include(": 2 done,")])
      end

      it "keeps the done tasks an agent worked on a model" do
        visit_review(day: "2026-09-16", model: "claude-sonnet-5")

        expect(done_titles).to eq(["Sonnet's"])
      end

      it "offers each agent and model the tasks name, with the one picked selected", :aggregate_failures do
        visit_review(day: "2026-09-16", model: "claude-sonnet-5")

        expect(page.all("#review-agent option").map(&:text)).to eq(["Any agent", "claude-code"])
        expect(page.find("#review-model option[selected]").text).to eq("claude-sonnet-5")
      end

      it "keeps the filter on the arrows" do
        visit_review(day: "2026-09-16", contributor: "agent")

        expect(page).to have_link("Previous week", href: "/admin/review?day=2026-09-09&contributor=agent")
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
        expect(card("done").all(".review-line").map(&:text)).to eq(["Done on the first", "Done on the last"])
      end

      it "counts the days worked across the month" do
        expect(card("worked").find(".review-stat small").text).to eq("1h 30m avg · 2 days worked")
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
    end

    describe "an empty period" do
      before { visit_review(day: "2001-01-03") }

      {
        "done" => "Nothing done yet", "carried" => "Nothing slipped", "published" => "Nothing went out",
        "commits" => "No commits", "decisions" => "No decisions closed", "journal" => "No entries yet",
        "worked" => "No time logged",
      }.each do |name, text|
        it "says #{name} holds nothing" do
          expect(card(name)).to have_css(".empty", text:)
        end
      end

      it "sums an empty journal" do
        expect(card("journal").find(".review-stat").text).to eq("0 entries · 0 words · 0 days written")
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
