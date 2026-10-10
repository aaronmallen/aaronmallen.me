# frozen_string_literal: true

RSpec.describe "Admin activity", :frozen_clock, type: :request do
  let(:page) { Capybara.string(last_response.body) }
  let(:today) { Blog::TimeZone.today }
  let(:week_ago) { today - 6 }

  def at(hour, minute = 0, on: today) = Blog::TimeZone.local_time(on.year, on.month, on.day, hour, minute)

  def count_for(type) = page.find(".activity-type:has(.fa-#{icon_for(type)}) .activity-type-count").text

  def date_text(date) = date.strftime("%b %-d, %Y")

  def day_names(date)
    page.all(".activity-day:has(time[datetime='#{date.iso8601}']) .activity-event-name").map(&:text)
  end

  def event_names = page.all(".activity-event-name").map(&:text)

  def event_subs = page.all(".activity-event-sub").map(&:text)

  def follow_event(name, params = {})
    visit_activity(params)
    get(page.find("a.activity-event", text: name)[:href].split("#").first)
  end

  def icon_for(type)
    {
      "comment" => "comment", "commit" => "code-commit", "decision" => "scale-balanced",
      "decision_comment" => "comments", "journal" => "feather", "post" => "file-lines", "session" => "clock",
      "social" => "paper-plane", "task" => "circle-check", "webmention" => "at",
      "pull_request_opened" => "code-pull-request", "pull_request_merged" => "code-merge",
      "pull_request_closed" => "circle-xmark",
    }.fetch(type)
  end

  def visit_activity(params = {}) = get("/admin/activity", params)

  describe "signed in" do
    before { sign_in_to_admin }

    describe "the page" do
      before { visit_activity }

      it "says activity is where you are" do
        expect(page).to have_css(".screen-tab[aria-current='page']", text: "activity")
      end

      it "shows the timeline icon in the palette" do
        expect(page).to have_css("#command-palette-activity i.fa-timeline", visible: :all)
      end

      it "renders the heading" do
        expect(page).to have_css(".page-head h1", text: "Activity")
      end

      it "lays out the filters in a bar above the timeline" do
        expect(page).to have_css(".activity-bar + .card")
      end

      it "groups the types as chips under one label" do
        expect(page).to have_css(".activity-types[role='group'][aria-label='Include'] label.activity-type", count: 13)
      end

      it "ties the search hint to the search box" do
        expect(page).to have_css("#activity-q[aria-describedby='activity-q-hint']").and have_css("p#activity-q-hint")
      end

      it "names the range in the sub-line" do
        expect(page).to have_css(".page-head-sub", text: "#{date_text(week_ago)} → #{date_text(today)}")
      end

      it "counts nothing when there is nothing" do
        expect(page).to have_css(".page-head-sub", text: "0 events across 0 days")
      end

      it "shows the empty state" do
        expect(page).to have_css(".empty", text: "Nothing in this range with these filters")
      end

      it "checks every type" do
        expect(page).to have_css(".activity-type input[type='checkbox'][checked]", count: 13, visible: :all)
      end

      it "submits the filters as a get" do
        expect(page).to have_css("form[method='get'][action='/admin/activity'][data-autosubmit]")
      end

      it "puts the Apply button after the filters" do
        expect(page).to have_css(
          "form[action='/admin/activity'] > .activity-hint + noscript button", text: "Apply", visible: :all,
        )
      end
    end

    describe "the timeline" do
      before do
        create(:post, :published, title: "Hello", slug: "hello", published_at: at(9))
        create(:journal_entry, entry_date: today - 1, entry_time: "21:15", body: "walked the dog")
        create(:commit, commit_date: today, commit_time: "08:00", message: "add the view")
        visit_activity
      end

      it "groups the days newest first" do
        expect(page.all(".day-date").map { it["datetime"] }).to eq([today.iso8601, (today - 1).iso8601])
      end

      it "orders a day's events newest first" do
        expect(day_names(today)).to eq(["Hello", "add the view"])
      end

      it "puts each day's events under its own heading" do
        expect(day_names(today - 1)).to eq(["walked the dog"])
      end

      it "heads today with its relative label and count" do
        expect(page).to have_css(".day-note", text: "Today · 2")
      end

      it "heads yesterday with its relative label" do
        expect(page).to have_css(".day-note", text: "Yesterday · 1")
      end

      it "heads each day on the card ground" do
        expect(page).to have_css(".activity-bar + .card .day-head.sunk", count: 2)
      end

      it "shows the time each event happened" do
        expect(page).to have_css(".activity-event-time", text: "08:00")
      end

      it "names a commit by its short sha" do
        create(:commit, repo: "aaronmallen/blog", sha: "9f8e7d6#{'0' * 33}", additions: 3, deletions: 1,
                        commit_date: today - 1)
        visit_activity

        expect(event_subs).to include("aaronmallen/blog · 9f8e7d6 · +3/−1")
      end

      it "counts the events in the sub-line" do
        expect(page).to have_css(".page-head-sub", text: "3 events across 2 days")
      end

      it "sets journal text in the serif face" do
        expect(page).to have_css(".activity-event-name.prose", text: "walked the dog")
      end

      it "leaves a commit name in the display face" do
        expect(page).to have_no_css(".activity-event-name.prose", text: "add the view")
      end
    end

    describe "tasks" do
      it "shows a completed task on the day it was finished" do
        create(:task, :done, title: "clear the gutters", completed_at: at(16, on: today - 1))
        visit_activity

        expect(day_names(today - 1)).to eq(["clear the gutters"])
      end

      it "says it is done by me when it lists no one" do
        create(:task, :done, completed_at: at(16))
        visit_activity

        expect(event_subs).to eq(["done by me"])
      end

      def credit_tasks
        create(:task, :done, title: "Mine", completed_at: at(16))
        shared = create(:task, :done, title: "Shared", completed_at: at(15))
        create(:task_contributor, :owner, task_id: shared.id)
        create(:task_contributor, task_id: shared.id)
        sonnet = create(:task, :done, title: "Sonnet's", completed_at: at(14))
        create(:task_contributor, task_id: sonnet.id, model: "claude-sonnet-5")
        create(:journal_entry, body: "A note", entry_date: today, entry_time: "09:00")
      end

      it "says who did each task" do
        credit_tasks
        visit_activity(types: { task: "1" })

        expect(event_subs).to eq(
          ["done by me", "done by me, claude-code on claude-opus-5-5", "done by claude-code on claude-sonnet-5"],
        )
      end

      it "keeps the tasks that list me, the default included, and drops every other kind" do
        credit_tasks
        visit_activity(q: "contributor:owner")

        expect(event_names).to eq(%w[Mine Shared])
      end

      it "keeps the tasks an agent worked on" do
        credit_tasks
        visit_activity(q: "agent:claude-code")

        expect(event_names).to eq(["Shared", "Sonnet's"])
      end

      it "keeps the tasks an agent worked on a model" do
        credit_tasks
        visit_activity(q: "model:claude-sonnet-5")

        expect(event_names).to eq(["Sonnet's"])
      end

      it "leaves out a canceled task" do
        create(:task, :canceled, title: "clear the gutters", completed_at: at(16))
        visit_activity

        expect(event_names).to be_empty
      end

      it "leaves out a task that is still open" do
        create(:task, title: "clear the gutters")
        visit_activity

        expect(event_names).to be_empty
      end

      it "counts the completed tasks in the range" do
        create(:task, :done, completed_at: at(16))
        create(:task, title: "still open")
        visit_activity

        expect(count_for("task")).to eq("1")
      end
    end

    describe "comments" do
      let(:task) { create(:task, title: "clear the gutters", tags: %w[home]) }

      def comment(*traits, **attrs) = create(:task_comment, *traits, task_id: task.id, created_at: at(10), **attrs)

      it "shows a local comment on the day it was made" do
        comment(body: "bought a ladder", created_at: at(10, on: today - 1))
        visit_activity

        expect(day_names(today - 1)).to eq(["bought a ladder"])
      end

      it "shows a synced comment too" do
        comment(:synced, body: "from the issue")
        visit_activity

        expect(event_names).to eq(["from the issue"])
      end

      it "names the task it is on" do
        comment
        visit_activity

        expect(event_subs).to eq(["on clear the gutters"])
      end

      it "shows a comment on a task that is still open" do
        comment(body: "bought a ladder")
        visit_activity

        expect(event_names).to eq(["bought a ladder"])
      end

      it "opens the comment on its task" do
        made = comment(body: "bought a ladder")
        visit_activity

        expect(page).to have_css(
          "a.activity-event[href='/admin/tasks/#{task.id}#task-comment-#{made.id}']", text: "bought a ladder",
        )
      end

      it "sets the comment's markdown as inline text" do
        comment(body: "bought a **ladder**")
        visit_activity

        expect(page).to have_css(".activity-event-name.prose strong", text: "ladder")
      end

      it "counts the comments in the range" do
        comment
        comment(:synced)
        comment(created_at: at(10, on: today - 30))
        visit_activity

        expect(count_for("comment")).to eq("2")
      end

      it "finds a comment by its task's title" do
        comment(body: "bought a ladder")
        visit_activity(q: "gutters")

        expect(event_names).to eq(["bought a ladder"])
      end

      it "finds a comment by its task's tags" do
        comment(body: "bought a ladder")
        create(:task_comment, body: "elsewhere", created_at: at(10))
        visit_activity(q: "tag:home")

        expect(event_names).to eq(["bought a ladder"])
      end

      it "leaves out a comment whose task carries another tag" do
        comment(body: "bought a ladder")
        visit_activity(q: "tag:work")

        expect(event_names).to be_empty
      end

      it "drops the comments when their type is unchecked" do
        comment
        visit_activity(types: { comment: "0", task: "1" })

        expect(event_names).to be_empty
      end
    end

    describe "work sessions" do
      let(:task) { create(:task, :in_progress, title: "clear the gutters", tags: %w[home]) }

      def session(started, ended = started + 5400, **attrs)
        create(:work_session, task_id: task.id, started_at: started, ended_at: ended, **attrs)
      end

      it "shows a closed session on the day it started, named for its task" do
        session(at(9, on: today - 1))
        visit_activity

        expect(day_names(today - 1)).to eq(["clear the gutters"])
      end

      it "says how long it ran" do
        session(at(9), at(10, 30))
        visit_activity

        expect(event_subs).to eq(["worked 1h 30m"])
      end

      it "shows a session on a task that is not done" do
        session(at(9))
        visit_activity

        expect(event_names).to eq(["clear the gutters"])
      end

      it "shows a session on a task that is done beside the task" do
        done = create(:task, :done, title: "paint the fence", completed_at: at(16))
        create(:work_session, task_id: done.id, started_at: at(9), ended_at: at(10))
        visit_activity

        expect(event_subs).to contain_exactly("done by me", "worked 1h 00m")
      end

      it "shows a session that crosses midnight on the day it started", :aggregate_failures do
        session(at(23, on: today - 2), at(1, on: today - 1))
        visit_activity

        expect(day_names(today - 2)).to eq(["clear the gutters"])
        expect(day_names(today - 1)).to be_empty
      end

      it "leaves out a session that is still running" do
        create(:work_session, task_id: task.id, started_at: at(9, on: today - 1))
        visit_activity

        expect(event_names).to be_empty
      end

      it "opens the session on its task" do
        made = session(at(9))
        visit_activity

        expect(page).to have_css(
          "a.activity-event[href='/admin/tasks/#{task.id}#task-session-#{made.id}']", text: "clear the gutters",
        )
      end

      it "counts the sessions in the range" do
        session(at(9))
        session(at(13))
        session(at(9, on: today - 30))
        visit_activity

        expect(count_for("session")).to eq("2")
      end

      it "finds a session by its task's tags" do
        session(at(9))
        create(:work_session, :closed, started_at: at(8), ended_at: at(9))
        visit_activity(q: "tag:home")

        expect(event_names).to eq(["clear the gutters"])
      end

      it "drops the sessions when their type is unchecked" do
        session(at(9))
        visit_activity(types: { comment: "1", session: "0" })

        expect(event_names).to be_empty
      end
    end

    describe "a task's moves, tags and status changes" do
      let(:task) { create(:task, title: "clear the gutters") }

      def event(kind, **columns)
        create(:task_event, task_id: task.id, kind:, tag_name: nil, occurred_at: at(9), **columns)
      end

      before do
        event("moved", from_list: "next", to_list: "someday")
        event("tagged", tag_name: "home")
        event("untagged", tag_name: "home")
        event("status_changed", from_status: "open", to_status: "in_progress")
      end

      it "leaves them out of the timeline" do
        visit_activity

        expect(event_names).to be_empty
      end
    end

    describe "decisions" do
      let(:decision) { create(:decision, title: "Pick a queue", tags: %w[infra]) }

      def comment(**attrs) = create(:decision_comment, decision_id: decision.id, created_at: at(11), **attrs)

      def event(kind, **attrs) = create(:decision_event, decision_id: decision.id, kind:, created_at: at(10), **attrs)

      def every_event
        option_id = create(:decision_option, decision_id: decision.id, title: "Sidekiq").id

        [
          event("opened"), event("option_added", option_id:), event("option_edited", option_id:),
          event("edited", note: "Fixed a typo"), event("resolved", option_id:, reason: "It already runs"),
          event("dropped", reason: "Not worth it"), event("reopened", reason: "Jobs pile up again"),
        ]
      end

      def every_sub_line
        [
          "opened", "option added · Sidekiq", "option edited · Sidekiq", "edited · Fixed a typo",
          "resolved · It already runs", "dropped · Not worth it", "reopened · Jobs pile up again",
        ]
      end

      def opening(selector = "") = page.all("a.activity-event[href='/admin/decisions/#{decision.id}'] #{selector}")

      it "shows every kind of event, each opening its decision" do
        every_event
        visit_activity

        expect(opening(".activity-event-name").map(&:text)).to eq(["Pick a queue"] * 7)
      end

      it "says what happened in each event's sub-line" do
        every_event
        visit_activity

        expect(event_subs).to match_array(every_sub_line)
      end

      it "shows a comment's markdown, opening its decision" do
        comment(body: "Ask **ops** first")
        visit_activity

        expect(opening(".activity-event-name.prose strong").map(&:text)).to eq(["ops"])
      end

      it "names the decision a comment is on" do
        comment
        visit_activity

        expect(event_subs).to eq(["on Pick a queue"])
      end

      it "counts events and comments apart", :aggregate_failures do
        event("opened")
        comment
        visit_activity

        expect(count_for("decision")).to eq("1")
        expect(count_for("decision_comment")).to eq("1")
      end

      it "finds a decision's events and comments by its tags" do
        event("opened")
        comment(body: "Ask ops first")
        create(:decision_event, kind: "opened", created_at: at(12))
        visit_activity(q: "tag:infra")

        expect(event_names).to contain_exactly("Pick a queue", "Ask ops first")
      end

      it "leaves out a decision that carries another tag" do
        event("opened")
        comment
        visit_activity(q: "tag:work")

        expect(event_names).to be_empty
      end

      it "drops the decisions when their type is unchecked" do
        event("opened")
        comment(body: "Ask ops first")
        visit_activity(types: { decision: "0", decision_comment: "1" })

        expect(event_names).to eq(["Ask ops first"])
      end
    end

    describe "pull requests" do
      def hrefs = page.all("a.activity-event").map { it[:href] }

      def pull_request(**times)
        create(:pull_request, repo: "aaronmallen/blog", title: "Add feeds", ready_at: at(9), **times)
      end

      it "opens each row on the pull request's page" do
        pull = pull_request(merged_at: at(10))
        visit_activity

        expect(hrefs).to eq(["/admin/pull-requests/#{pull.id}"] * 2)
      end

      it "shows an opened row and a merged row for a merged one" do
        pull_request(merged_at: at(10))
        visit_activity

        expect(event_subs).to eq(["merged into aaronmallen/blog", "opened in aaronmallen/blog"])
      end

      it "shows an opened row and a closed row for one closed without a merge" do
        pull_request(closed_at: at(10))
        visit_activity

        expect(event_subs).to eq(["closed in aaronmallen/blog", "opened in aaronmallen/blog"])
      end

      it "shows only the opened row for an open one" do
        pull_request
        visit_activity

        expect(event_subs).to eq(["opened in aaronmallen/blog"])
      end

      it "shows nothing for one that was never ready" do
        pull_request(ready_at: nil, closed_at: at(10))
        visit_activity

        expect(event_names).to be_empty
      end

      it "counts each kind apart" do
        [{ merged_at: at(10) }, { closed_at: at(11) }].each { pull_request(**it) }
        visit_activity

        expect(%w[opened merged closed].map { count_for("pull_request_#{it}") }).to eq(%w[2 1 1])
      end

      it "drops a kind when its type is unchecked" do
        pull_request(merged_at: at(10))
        visit_activity(types: { pull_request_opened: "0", pull_request_merged: "1" })

        expect(event_subs).to eq(["merged into aaronmallen/blog"])
      end
    end

    describe "a day older than yesterday" do
      before do
        create(:commit, commit_date: today - 3, message: "add the view")
        visit_activity
      end

      it "heads it with how long ago it was" do
        expect(page).to have_css(".day-note", text: "3 days ago · 1")
      end
    end

    describe "the range" do
      before do
        create(:commit, commit_date: today - 20, message: "older")
        create(:commit, commit_date: today, message: "newer")
      end

      it "holds the last 7 days by default" do
        visit_activity

        expect(event_names).to eq(["newer"])
      end

      it "reaches back to a From that is given" do
        visit_activity(from: (today - 30).iso8601, to: today.iso8601)

        expect(event_names).to eq(%w[newer older])
      end

      it "stops From at To" do
        visit_activity

        expect(page).to have_css("#activity-from[max='#{today.iso8601}']")
      end

      it "stops To at From" do
        visit_activity

        expect(page).to have_css("#activity-to[min='#{week_ago.iso8601}']")
      end

      it "leaves From open at the start of the data" do
        visit_activity

        expect(page).to have_no_css("#activity-from[min]")
      end

      it "pulls a From after To back to To" do
        visit_activity(from: (today + 5).iso8601, to: today.iso8601)

        expect(page).to have_css("#activity-from[value='#{today.iso8601}']")
      end

      it "falls back to the default range for a From that is not a date" do
        visit_activity(from: "soon")

        expect(page).to have_css("#activity-from[value='#{week_ago.iso8601}']")
      end

      %w[99999999-01-01 -4800-01-01].each do |date|
        it "falls back to the default range for a From of #{date}" do
          visit_activity(from: date)

          expect(page).to have_css("#activity-from[value='#{week_ago.iso8601}']")
        end

        it "falls back to today for a To of #{date}" do
          visit_activity(to: date)

          expect(page).to have_css("#activity-to[value='#{today.iso8601}']")
        end
      end
    end

    describe "paging" do
      let(:range) { { from: (today - 29).iso8601, to: today.iso8601 } }

      def activity_reads(day)
        counting { visit_activity(range.merge(day: day.iso8601)) }.grep(/FROM "activities"/).length
      end

      def back_from_third_page
        lower_page_size(:admin, to: 1)
        visit_activity(range)
        2.times { follow(older_href) }
        follow(newer_href)
      end

      def follow(href) = get(href)

      def newer_href = page.find("a.pager-link[rel='prev']")[:href]

      def older_href = page.find("a.pager-link[rel='next']")[:href]

      def page = Capybara.string(last_response.body)

      before do
        lower_page_size(:admin, to: 2)
        create(:commit, commit_date: today, message: "today")
        create(:commit, commit_date: today - 1, message: "yesterday one")
        create(:commit, commit_date: today - 1, message: "yesterday two")
        create(:commit, commit_date: today - 3, message: "three days ago")
        create(:commit, commit_date: today - 20, message: "twenty days ago")
      end

      it "stops near the page size and finishes the day it is on" do
        visit_activity(range)

        expect(page.all(".day-date").map { it["datetime"] }).to eq([today.iso8601, (today - 1).iso8601])
      end

      it "shows the rest of the range on the older page" do
        visit_activity(range)
        follow(older_href)

        expect(event_names).to eq(["three days ago", "twenty days ago"])
      end

      it "keeps the range on the older page", :aggregate_failures do
        visit_activity(range)
        follow(older_href)

        expect(page).to have_css("#activity-from[value='#{range[:from]}']")
        expect(page).to have_css("#activity-to[value='#{range[:to]}']")
      end

      it "keeps the filters on the older page" do
        visit_activity(range.merge(q: "o"))

        expect(older_href).to include("q=o")
      end

      it "offers no newer link on the first page" do
        visit_activity(range)

        expect(page).to have_no_css("a.pager-link[rel='prev']")
      end

      it "offers no older link on the last page" do
        visit_activity(range)
        follow(older_href)

        expect(page).to have_no_css("a.pager-link[rel='next']")
      end

      it "links back to the newer page" do
        visit_activity(range)
        first_page = event_names
        follow(older_href)
        follow(newer_href)

        expect(event_names).to eq(first_page)
      end

      it "leaves the day off the link back to the first page" do
        visit_activity(range)
        follow(older_href)

        expect(newer_href).not_to include("day=")
      end

      it "links from the third page back to the page in between" do
        back_from_third_page

        expect(event_names).to contain_exactly("yesterday one", "yesterday two")
      end

      it "links from the page in between back to the first" do
        back_from_third_page

        expect(newer_href).not_to include("day=")
      end

      it "reads the activities as often for the newer link on a deep page as on a shallow one" do
        lower_page_size(:admin, to: 1)
        (21..25).each { create(:commit, commit_date: today - it) }

        expect(activity_reads(today - 20)).to eq(activity_reads(today - 1))
      end

      it "links from a day past the oldest event to the last page that holds one" do
        visit_activity(range.merge(day: (today - 25).iso8601))
        follow(newer_href)

        expect(event_names).to eq(["three days ago", "twenty days ago"])
      end

      it "counts every event in the range, not one page" do
        visit_activity(range)

        expect(page).to have_css(".page-head-sub", text: "5 events across 4 days")
      end

      it "counts every event in the rail, not one page" do
        visit_activity(range)

        expect(count_for("commit")).to eq("5")
      end

      it "starts at the end of the range for a day outside it" do
        visit_activity(range.merge(day: (today + 3).iso8601))

        expect(event_names).to include("today")
      end

      it "starts at the end of the range for a day that is not a date" do
        visit_activity(range.merge(day: "soon"))

        expect(event_names).to include("today")
      end

      it "starts at the end of the range for a day past four-digit years" do
        visit_activity(range.merge(day: "99999999-01-01"))

        expect(event_names).to include("today")
      end

      it "keeps the paging links working with scripts off" do
        visit_activity(range)

        expect(page).to have_css("nav.pager a.pager-link[rel='next'][href^='/admin/activity?']", text: "Older")
      end
    end

    describe "paging across the edges of the range" do
      let(:first_day) { today - 29 }
      let(:range) { { from: first_day.iso8601, to: today.iso8601 } }

      def commits_on(*days) = days.each { create(:commit, commit_date: it, message: "on #{it.iso8601}") }

      before { lower_page_size(:admin, to: 2) }

      it "points past the gap to the day before the last one it answered", :aggregate_failures do
        lower_page_size(:admin, to: 1)
        commits_on(today, today - 5)
        visit_activity(range)

        expect(event_names).to eq(["on #{today.iso8601}"])
        expect(page.find("a.pager-link[rel='next']")[:href]).to include("day=#{(today - 1).iso8601}")
      end

      it "shows the whole last day when it holds the rest of the range", :aggregate_failures do
        commits_on(today - 1, today - 1, today - 1)
        visit_activity(range)

        expect(event_names.length).to eq(3)
        expect(page).to have_no_css("a.pager-link[rel='next']")
      end

      it "offers no older link when the page ends on the first day of the range", :aggregate_failures do
        commits_on(first_day, first_day, first_day + 1)
        visit_activity(range)

        expect(event_names.length).to eq(3)
        expect(page).to have_no_css("a.pager-link[rel='next']")
      end
    end

    describe "the presets" do
      it "marks 7d active by default" do
        visit_activity

        expect(page).to have_css("nav.seg[aria-label='Range'] a.seg-option.current[aria-current='page']", text: "7d")
      end

      it "marks 30d active when the dates match it" do
        visit_activity(from: (today - 29).iso8601, to: today.iso8601)

        expect(page).to have_css(".seg-option.current", text: "30d")
      end

      it "marks nothing active for dates that match no preset" do
        visit_activity(from: (today - 3).iso8601, to: today.iso8601)

        expect(page).to have_no_css(".seg-option.current")
      end

      it "sets the dates through its link" do
        visit_activity

        expect(page.find(".seg-option", text: "90d")[:href])
          .to start_with("/admin/activity?from=#{today - 89}&to=#{today}")
      end

      it "keeps the other filters in its link" do
        visit_activity(q: "repo:aaronmallen/one views")

        expect(page.find(".seg-option", text: "30d")[:href]).to include("q=repo%3Aaaronmallen%2Fone+views")
      end
    end

    describe "the types" do
      let(:without_posts) { { commit: "1", journal: "1", post: "0", social: "1", task: "1", webmention: "1" } }

      before do
        create(:post, :published, title: "Hello", published_at: at(9))
        create(:commit, commit_date: today, message: "add the view")
      end

      it "drops the events of an unchecked type" do
        visit_activity(types: without_posts)

        expect(event_names).to eq(["add the view"])
      end

      it "leaves an unchecked type unchecked" do
        visit_activity(types: without_posts)

        expect(page).to have_css(
          ".activity-type:has(.fa-file-lines) input[type='checkbox']:not([checked])", visible: :all,
        )
      end

      it "shows nothing when no type is checked" do
        visit_activity(types: without_posts.transform_values { "0" })

        expect(page).to have_css(".empty")
      end

      it "counts the events of a checked type" do
        visit_activity

        expect(count_for("commit")).to eq("1")
      end

      it "counts what an unchecked type would add" do
        visit_activity(types: without_posts)

        expect(count_for("post")).to eq("1")
      end

      it "counts zero for a type with nothing in range" do
        visit_activity

        expect(count_for("journal")).to eq("0")
      end

      it "leaves out a project and a sprint, which the timeline does not show" do
        create(:project, name: "blog")
        create(:sprint, sprint_date: today)
        visit_activity

        expect(event_names).to contain_exactly("Hello", "add the view")
      end

      it "offers no checkbox for a project, a sprint or a suggestion" do
        visit_activity

        expect(page).to have_no_css("input[name='types[project]'], input[name='types[sprint]'], " \
                                    "input[name='types[suggestion]']", visible: :all)
      end

      it "draws a type as a plain checkbox, not a switch" do
        visit_activity

        expect(page).to have_css("input[type='checkbox'][name='types[post]']:not([role])", visible: :all)
      end
    end

    describe "searching by repo" do
      before do
        create(:commit, repo: "aaronmallen/one", commit_date: today, message: "in one")
        create(:commit, repo: "aaronmallen/two", commit_date: today, message: "in two")
        create(:journal_entry, entry_date: today, body: "walked the dog")
      end

      it "keeps the commits of the repo named" do
        visit_activity(q: "repo:aaronmallen/one")

        expect(event_names).to include("in one")
      end

      it "drops the commits of every other repo" do
        visit_activity(q: "repo:aaronmallen/one")

        expect(event_names).not_to include("in two")
      end

      it "keeps the commits of every repo named" do
        visit_activity(q: "repo:aaronmallen/one repo:aaronmallen/two")

        expect(event_names).to include("in one", "in two")
      end

      it "drops the pull requests of every other repo" do
        create(:pull_request, repo: "aaronmallen/one", title: "pr in one", ready_at: Time.now)
        create(:pull_request, repo: "aaronmallen/two", title: "pr in two", ready_at: Time.now)
        visit_activity(q: "repo:aaronmallen/one")

        expect(event_names & ["pr in one", "pr in two"]).to eq(["pr in one"])
      end

      it "leaves the other types alone when it names two repos" do
        visit_activity(q: "repo:aaronmallen/one repo:aaronmallen/two")

        expect(event_names).to include("walked the dog")
      end

      it "leaves the other types alone" do
        visit_activity(q: "repo:aaronmallen/one")

        expect(event_names).to include("walked the dog")
      end

      it "finds the repo whatever case the query uses" do
        visit_activity(q: "repo:AaronMallen/One")

        expect(event_names).to include("in one")
      end

      it "finds a repo named without its owner" do
        visit_activity(q: "repo:one")

        expect(event_names).to include("in one")
      end

      it "shows no commit for a repo that has none, and no error" do
        visit_activity(q: "repo:aaronmallen/gone")

        expect(event_names).to eq(["walked the dog"])
      end

      it "searches the words beside the repo as text" do
        visit_activity(q: "repo:aaronmallen/one in")

        expect(event_names).to eq(["in one"])
      end

      it "narrows the counts too", :aggregate_failures do
        visit_activity(q: "repo:aaronmallen/one")

        expect(count_for("commit")).to eq("1")
        expect(count_for("journal")).to eq("1")
      end

      it "keeps the query in the field" do
        visit_activity(q: "repo:aaronmallen/one")

        expect(page).to have_field("Contains", with: "repo:aaronmallen/one")
      end
    end

    describe "contains" do
      before do
        create(:commit, commit_date: today, message: "add the Activities view")
        create(:post, :published, title: "Hello", slug: "on-views", published_at: at(9))
        create(:commit, commit_date: today, message: "nothing to see")
      end

      it "matches a name, ignoring case" do
        visit_activity(q: "ACTIVITIES")

        expect(event_names).to eq(["add the Activities view"])
      end

      it "matches a sub-line, ignoring case" do
        visit_activity(q: "On-Views")

        expect(event_names).to eq(["Hello"])
      end

      it "matches a commit body the row never shows" do
        create(:commit, commit_date: today, message: "tidy the imports\n\nthe lockfile drifted")
        visit_activity(q: "lockfile")

        expect(event_names).to eq(["tidy the imports"])
      end

      it "keeps the text in the field" do
        visit_activity(q: "ACTIVITIES")

        expect(page).to have_field("Contains", with: "ACTIVITIES")
      end

      it "narrows the counts too" do
        visit_activity(q: "ACTIVITIES")

        expect(count_for("commit")).to eq("1")
      end
    end

    describe "searching by tag" do
      before do
        create(:journal_entry, entry_date: today, body: "walked the dog", tags: %w[health])
        create(:journal_entry, entry_date: today, body: "read the docs", tags: %w[ruby])
        create(:commit, commit_date: today, message: "ruby: add the view")
      end

      it "returns the entries carrying the tag and nothing else" do
        visit_activity(q: "tag:ruby")

        expect(event_names).to eq(["read the docs"])
      end

      it "finds the tag whatever case the query uses" do
        visit_activity(q: "tag:RUBY")

        expect(event_names).to eq(["read the docs"])
      end

      it "asks for both tags when the query names two" do
        create(:journal_entry, entry_date: today, body: "wrote the post", tags: %w[ruby writing])
        visit_activity(q: "tag:ruby tag:writing")

        expect(event_names).to eq(["wrote the post"])
      end

      it "searches the words beside the tag as text" do
        create(:journal_entry, entry_date: today, body: "read the news", tags: %w[ruby])
        visit_activity(q: "tag:ruby docs")

        expect(event_names).to eq(["read the docs"])
      end

      it "narrows the counts too", :aggregate_failures do
        visit_activity(q: "tag:ruby")

        expect(count_for("journal")).to eq("1")
        expect(count_for("commit")).to eq("0")
      end

      it "keeps the query in the field" do
        visit_activity(q: "tag:ruby")

        expect(page).to have_field("Contains", with: "tag:ruby")
      end

      it "shows nothing for a tag no entry carries" do
        visit_activity(q: "tag:rust")

        expect(event_names).to be_empty
      end

      it "returns the completed tasks carrying the tag too" do
        create(:task, :done, title: "clear the gutters", completed_at: at(16), tags: %w[ruby])
        visit_activity(q: "tag:ruby")

        expect(event_names).to contain_exactly("read the docs", "clear the gutters")
      end

      it "leaves out a task carrying another tag" do
        create(:task, :done, title: "clear the gutters", completed_at: at(16), tags: %w[home])
        visit_activity(q: "tag:ruby")

        expect(event_names).to eq(["read the docs"])
      end

      it "counts the tagged tasks too" do
        create(:task, :done, title: "clear the gutters", completed_at: at(16), tags: %w[ruby])
        visit_activity(q: "tag:ruby")

        expect(count_for("task")).to eq("1")
      end
    end

    describe "opening an event" do
      it "opens a post in the editor" do
        post = create(:post, :published, title: "Hello", slug: "hello", published_at: at(9))
        visit_activity

        expect(page).to have_css("a.activity-event[href='/admin/posts/#{post.id}/edit']", text: "Hello")
      end

      it "opens a journal entry on its day" do
        create(:journal_entry, entry_date: today - 1, body: "walked the dog")
        visit_activity

        expect(page).to have_css(
          "a.activity-event[href='/admin/journal?to=#{today - 1}#day-#{today - 1}']", text: "walked the dog",
        )
      end

      it "opens a journal entry past the journal's first page on the page that holds it" do
        lower_page_size(:admin, to: 1)
        create(:journal_entry, entry_date: today - 1)
        create(:journal_entry, entry_date: today - 3, body: "walked the dog")
        follow_event("walked the dog", day: today - 3)

        expect(last_response.body).to include("walked the dog")
      end

      it "opens a social post in the queue" do
        create(:social_post, :posted, posted_at: at(12))
        visit_activity

        expect(page).to have_link(class: "activity-event", href: "/admin/social?filter=posted")
      end

      it "opens a task on the tasks page" do
        create(:task, :done, title: "clear the gutters", completed_at: at(16))
        visit_activity

        expect(page).to have_link("clear the gutters", href: "/admin/tasks")
      end

      it "opens a webmention on the webmentions page" do
        post = create(:post, :published, slug: "hello")
        create(:webmention, :approved, post_id: post.id, author_name: "Ada", received_at: at(8))
        visit_activity

        expect(page).to have_link("Ada", href: "/admin/webmentions")
      end

      it "opens a commit on its own page" do
        commit = create(:commit, commit_date: today, message: "add the view")
        visit_activity

        expect(page).to have_css("a.activity-event[href='/admin/commits/#{commit.id}']", text: "add the view")
      end

      it "names a commit by its subject, leaving the body to its page" do
        create(:commit, commit_date: today, message: "add the view\n\nwith a body that says more")
        visit_activity

        expect(event_names).to eq(["add the view"])
      end
    end

    describe "a post's sub-line" do
      before do
        create(:post, :published, title: "Hello", slug: "hello", published_at: at(9))
        create(:analytics_rollup, day: today)
        create(:analytics_rollup_path, day: today, path: "/writing/hello", views: 12, visitors: 8, bounces: 2)
        visit_activity
      end

      it "counts the views it has had" do
        expect(event_subs).to eq(["/writing/hello · published · 12 views"])
      end
    end

    describe "a post's sub-line with today's views not rolled up yet" do
      before do
        create(:post, :published, title: "Hello", slug: "hello", published_at: at(9))
        create(:analytics_rollup, day: today - 1)
        create(:analytics_rollup_path, day: today - 1, path: "/writing/hello", views: 12, visitors: 8, bounces: 2)
        create(:analytics_event, path: "/writing/hello", occurred_at: Blog::TimeZone.day_start(today - 1) + 60)
        2.times { create(:analytics_event, path: "/writing/hello") }
        visit_activity
      end

      it "adds today's views to the rolled up days, counting each rolled day once" do
        expect(event_subs).to eq(["/writing/hello · published · 14 views"])
      end
    end

    describe "a post's sub-line with one view" do
      before do
        create(:post, :published, title: "Hello", slug: "hello", published_at: at(9))
        create(:analytics_rollup, day: today)
        create(:analytics_rollup_path, day: today, path: "/writing/hello", views: 1, visitors: 1, bounces: 1)
        visit_activity
      end

      it "counts the one view" do
        expect(event_subs).to eq(["/writing/hello · published · 1 view"])
      end
    end

    describe "a webmention's sub-line" do
      let(:post) { create(:post, :published, slug: "hello", published_at: at(7, on: today - 1)) }

      it "names the post it is on and its excerpt" do
        create(:webmention, :approved, post_id: post.id, excerpt: "nice work", received_at: at(8))
        visit_activity(types: { webmention: "1" })

        expect(event_subs).to eq(["on /writing/hello · nice work"])
      end

      it "names only the post it is on without an excerpt" do
        create(:webmention, :approved, post_id: post.id, excerpt: nil, received_at: at(8))
        visit_activity(types: { webmention: "1" })

        expect(event_subs).to eq(["on /writing/hello"])
      end
    end

    describe "a journal row's markdown" do
      def name_html = page.find(".activity-event-name").native.inner_html

      def visit_entry(body)
        create(:journal_entry, entry_date: today, body:)
        visit_activity
      end

      it "formats bold, italic and code", :aggregate_failures do
        visit_entry("a **bold**, _italic_ and `code` day")

        expect(page).to have_css(".activity-event-name strong", text: "bold")
        expect(page).to have_css(".activity-event-name em", text: "italic")
        expect(page).to have_css(".activity-event-name code", text: "code")
      end

      it "shows a link as its text", :aggregate_failures do
        visit_entry("read [the docs](https://example.com/docs) today")

        expect(event_names).to eq(["read the docs today"])
        expect(page).to have_no_css("a.activity-event a")
      end

      it "flattens a heading, a list and paragraphs into one line" do
        visit_entry("# Morning\n\n- one\n- two\n\nwalked\nthe dog\n\n> and rested")

        expect(event_names).to eq(["Morning one two walked the dog and rested"])
      end

      it "cuts at the visible text and closes the mark it opened" do
        visit_entry("**#{(%w[bold] * 40).join(' ')}**")

        expect(name_html).to eq("<strong>#{(%w[bold] * 24).join(' ')}</strong>…")
      end

      it "closes every mark it opened when the cut falls inside two" do
        visit_entry("**bold _and #{(%w[long] * 30).join(' ')}_**")

        expect(name_html).to end_with("</em></strong>…")
      end

      it "leaves a link's address out of the count" do
        visit_entry("[docs](https://example.com/#{'a' * 200}) walked")

        expect(event_names).to eq(["docs walked"])
      end

      it "drops raw HTML", :aggregate_failures do
        visit_entry("a <script>alert(1)</script> <b>bold</b> <img src=x onerror=alert(2)> day")

        expect(page).to have_no_css(".activity-event-name script, .activity-event-name b, .activity-event-name img")
        expect(event_names).to eq(["a alert(1) bold day"])
      end

      it "escapes text that reads like HTML" do
        visit_entry("`<b>not bold</b>`")

        expect(page).to have_css(".activity-event-name code", text: "<b>not bold</b>")
      end

      it "leaves the markdown in other kinds alone", :aggregate_failures do
        create(:commit, commit_date: today, message: "add **the** view")
        visit_activity

        expect(event_names).to eq(["add **the** view"])
        expect(page).to have_no_css(".activity-event-name strong")
      end
    end

    describe "a long name" do
      before do
        create(:journal_entry, entry_date: today, body: "walked #{'the dog ' * 40}")
        visit_activity
      end

      it "cuts it short" do
        expect(event_names.first.length).to be <= 121
      end

      it "ends it with an ellipsis" do
        expect(event_names.first).to end_with("…")
      end
    end
  end
end
