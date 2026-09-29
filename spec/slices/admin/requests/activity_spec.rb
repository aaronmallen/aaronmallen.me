# frozen_string_literal: true

RSpec.describe "Admin activity", type: :request do
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

  def icon_for(type)
    { "commit" => "code-commit", "journal" => "feather", "post" => "file-lines", "social" => "paper-plane",
      "task" => "circle-check", "webmention" => "at" }.fetch(type)
  end

  def visit_activity(params = {}) = get("/admin/activity", params)

  describe "signed out" do
    it "redirects to sign-in" do
      visit_activity

      expect(last_response.location).to end_with("/admin/sign-in")
    end
  end

  describe "signed in" do
    before { sign_in_to_admin }

    describe "the page" do
      before { visit_activity }

      it "says activity is where you are" do
        expect(page).to have_css(".ctx-where", text: %r{Insights\s+/\s+activity})
      end

      it "shows the timeline icon in the palette" do
        expect(page).to have_css("#command-palette-activity i.fa-timeline", visible: :all)
      end

      it "renders the heading" do
        expect(page).to have_css(".page-head h1", text: "Activity")
      end

      it "lays out the filters beside the timeline" do
        expect(page).to have_css(".split > .activity-rail + .activity-main")
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
        expect(page).to have_css(".activity-type input[type='checkbox'][checked]", count: 6, visible: :all)
      end

      it "submits the filters as a get" do
        expect(page).to have_css("form[method='get'][action='/admin/activity'][data-autosubmit]")
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
        expect(page.all(".activity-day-date").map { it["datetime"] }).to eq([today.iso8601, (today - 1).iso8601])
      end

      it "orders a day's events newest first" do
        expect(day_names(today)).to eq(["Hello", "add the view"])
      end

      it "puts each day's events under its own heading" do
        expect(day_names(today - 1)).to eq(["walked the dog"])
      end

      it "heads today with its relative label and count" do
        expect(page).to have_css(".activity-day-count", text: "Today · 2")
      end

      it "heads yesterday with its relative label" do
        expect(page).to have_css(".activity-day-count", text: "Yesterday · 1")
      end

      it "shows the time each event happened" do
        expect(page).to have_css(".activity-event-time", text: "08:00")
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

      it "says it is done and names its type" do
        create(:task, :done, task_type_id: create(:task_type, name: "Chore").id, completed_at: at(16))
        visit_activity

        expect(event_subs).to eq(["done · Chore"])
      end

      it "says only that a task with no type is done" do
        create(:task, :done, completed_at: at(16))
        visit_activity

        expect(event_subs).to eq(["done"])
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

    describe "a day older than yesterday" do
      before do
        create(:commit, commit_date: today - 3, message: "add the view")
        visit_activity
      end

      it "heads it with how long ago it was" do
        expect(page).to have_css(".activity-day-count", text: "3 days ago · 1")
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
    end

    describe "the presets" do
      it "marks 7d active by default" do
        visit_activity

        expect(page).to have_css(".seg-option.current", text: "7d")
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
    end

    describe "searching by repo" do
      before do
        create(:commit, repo: "aaronmallen/one", commit_date: today, message: "in one")
        create(:commit, repo: "aaronmallen/two", commit_date: today, message: "in two")
        create(:journal_entry, entry_date: today, body: "walked the dog")
      end

      it "offers no repository dropdown" do
        visit_activity

        expect(page).to have_no_css("#activity-repo")
      end

      it "keeps the commits of the repo named" do
        visit_activity(q: "repo:aaronmallen/one")

        expect(event_names).to include("in one")
      end

      it "drops the commits of every other repo" do
        visit_activity(q: "repo:aaronmallen/one")

        expect(event_names).not_to include("in two")
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

        expect(page).to have_css("a.activity-event[href='/admin/journal#day-#{today - 1}']", text: "walked the dog")
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
