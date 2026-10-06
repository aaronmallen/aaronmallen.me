# frozen_string_literal: true

RSpec.describe "Admin time", :frozen_clock, type: :request do
  let(:page) { Capybara.string(last_response.body) }
  let(:site) { create(:project, name: "site") }
  let(:gem) { create(:project, name: "gem") }
  let(:today) { Blog::TimeZone.today }

  def at(day, hour, minute = 0) = Blog::TimeZone.local_time(2026, 3, day, hour, minute)

  def group(name) = page.find(".time-group", text: name)

  def link(task, *projects)
    projects.each do |project|
      Links::Slice["operations.link_records"].call("task", task.id, { other_kind: "project", other_id: project.id })
    end
    task
  end

  def rows = page.all(".time-row").map { [it.find(".meter-name").text, it.find(".meter-count").text] }

  def task_row(row)
    link = row.find_link(visible: :all)
    [link.text(:all), link[:href], row.find(".time-task-hours", visible: :all).text(:all)]
  end

  def tasks_in(name) = group(name).all(".li", visible: :all)

  def visit_time(params = {}) = get("/admin/time", params)

  def worked(title, from, to, tags: [])
    task = create(:task, :done, title:, tags:, worked_seconds: (to - from).to_i)
    create(:work_session, task_id: task.id, started_at: from, ended_at: to)
    task
  end

  describe "signed out" do
    it "redirects to sign-in" do
      visit_time

      expect(last_response.location).to end_with("/admin/sign-in")
    end
  end

  describe "signed in" do
    before { sign_in_to_admin }

    describe "with no range in the URL" do
      before { visit_time }

      it "says the time screen is where you are" do
        expect(page).to have_css(".ctx-where", text: %r{Insights\s+/\s+time})
      end

      it "lists the time screen in the palette with its icon" do
        expect(page).to have_css("#command-palette-time i.fa-clock", visible: :all)
      end

      it "covers the last seven days by tag" do
        expect([page.find_field("From").value, page.find_field("To").value, page.find_field("Tag")])
          .to match([(today - 6).iso8601, today.iso8601, be_checked])
      end

      it "offers tag first, then project, then day" do
        expect(page.all("[role='radiogroup'] .seg-option").map(&:text)).to eq(%w[Tag Project Day])
      end

      it "marks the seven day preset current" do
        expect(page).to have_css(".seg-option.current[aria-current='page']", text: "7d")
      end

      it "says no time was logged" do
        expect(page).to have_css("#time-groups .empty", text: "No time logged")
      end

      it "renders without a missing translation" do
        expect(last_response.body).not_to include("translation_missing")
      end
    end

    describe "a range grouped by project" do
      let!(:tasks) do
        {
          both: link(worked("Ship the shared work", at(2, 9), at(2, 10)), site, gem),
          alone: link(worked("Polish the site", at(3, 9), at(3, 9, 30)), site),
          loose: worked("Answer email", at(4, 9), at(4, 9, 15)),
        }
      end

      before do
        link(worked("Out of range", at(20, 9), at(20, 10)), site)
        visit_time(from: "2026-03-02", to: "2026-03-08", by: "project")
      end

      it "sums each project's time, with the tasks that have no project last" do
        expect(rows).to eq([["gem", "1h 00m"], ["site", "1h 30m"], ["No project", "15m"]])
      end

      it "totals the range once, however many projects a task counts in" do
        expect(page).to have_css(".page-head-sub", text: "Mar 2, 2026 → Mar 8, 2026 · 1h 45m")
      end

      it "flags the projects that share time with another" do
        flagged = page.all(".time-group").select { it.has_css?(".time-row .pill", text: "shared") }

        expect(flagged.map { it.find(".meter-name").text }).to eq(%w[gem site])
      end

      it "explains why the rows add up to more than the total" do
        expect(page).to have_css(".hint", text: "counts in each of its projects")
      end

      it "lists the tasks behind a row with their time, each linked to its page" do
        both, alone = tasks.values_at(:both, :alone).map { "/admin/tasks/#{it.id}" }

        expect(tasks_in("site").map { task_row(it) })
          .to eq([["Ship the shared work", both, "1h 00m"], ["Polish the site", alone, "30m"]])
      end

      it "flags only the shared task inside a row" do
        flagged = tasks_in("site").select { it.has_css?(".pill", text: "shared", visible: :all) }

        expect(flagged.map { it.find_link(visible: :all).text(:all) }).to eq(["Ship the shared work"])
      end

      it "lists the tasks with no project under their own row" do
        href = "/admin/tasks/#{tasks[:loose].id}"

        expect(group("No project")).to have_link("Answer email", href:, visible: :all)
      end

      it "opens a row without a script" do
        expect(page).to have_css("details.time-group > summary.time-row", count: 3)
      end

      it "keeps the grouping in the preset links" do
        href = "/admin/time?from=#{(today - 29).iso8601}&to=#{today.iso8601}&by=project"

        expect(page).to have_link("30d", href:)
      end
    end

    describe "a range grouped by tag" do
      before do
        worked("Tagged twice", at(2, 9), at(2, 10), tags: %w[ruby site])
        worked("Tagged once", at(3, 9), at(3, 9, 30), tags: %w[ruby])
        worked("Untagged", at(4, 9), at(4, 9, 15))
        visit_time(from: "2026-03-02", to: "2026-03-08", by: "tag")
      end

      it "sums each tag's time, with the untagged tasks last" do
        expect(rows).to eq([["ruby", "1h 30m"], ["site", "1h 00m"], ["No tag", "15m"]])
      end

      it "checks the tag grouping in the form" do
        expect(page.find_field("Tag")).to be_checked
      end

      it "explains why the rows add up to more than the total" do
        expect(page).to have_css(".hint", text: "counts under both")
      end

      it "groups by tag when the URL names no grouping" do
        visit_time(from: "2026-03-02", to: "2026-03-08")

        expect(rows).to eq([["ruby", "1h 30m"], ["site", "1h 00m"], ["No tag", "15m"]])
      end
    end

    describe "a range grouped by day" do
      before do
        link(worked("Ship the shared work", at(2, 9), at(2, 10)), site, gem)
        worked("Answer email", at(4, 9), at(4, 9, 15))
        visit_time(from: "2026-03-02", to: "2026-03-08", by: "day")
      end

      it "sums each day's time in order" do
        expect(rows).to eq([["Monday, March 2", "1h 00m"], ["Wednesday, March 4", "15m"]])
      end

      it "flags no day, since a day never shares time" do
        expect(page).to have_no_css(".pill")
      end
    end

    it "starts a range that runs backward on the day it ends" do
      visit_time(from: "2026-03-08", to: "2026-03-02")

      expect([page.find_field("From").value, page.find_field("To").value]).to eq(%w[2026-03-02 2026-03-02])
    end

    it "falls back to the last seven days by tag on values it cannot read" do
      visit_time(from: "nope", to: "2026-13-40", by: "year")

      expect([page.find_field("From").value, page.find_field("Tag")]).to match([(today - 6).iso8601, be_checked])
    end
  end
end
