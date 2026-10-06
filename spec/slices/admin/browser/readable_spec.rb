# frozen_string_literal: true

RSpec.describe "Admin screens", type: :feature do
  let(:commit) { create(:commit, message: "app: make the admin usable on a phone", repo: "aaronmallen/blog") }
  let(:draft) { create(:post, :draft, title: "A draft in progress") }
  let(:project) { create(:project, name: "aaronmallen.me", tagline: "This website") }
  let(:social_post) { create(:social_post, :draft) }
  let(:task) do
    create(
      :task, :carried,
      title: "Email the accountant about the quarterly filing",
      note: "some context from [the filing guide](https://example.com/guide), read [first](/admin)\n\n" \
            "- one\n- two\n\n- [ ] call the accountant\n- [x] find the forms\n\n" \
            "<details><summary>More</summary>\n\nhidden detail</details>\n\n" \
            "```\n#{'a_very_long_line_of_code ' * 8}\n```",
      tags: %w[site],
    )
  end

  def at(hour, minute) = Blog::TimeZone.local_time(today.year, today.month, today.day, hour, minute)

  def calendars
    { "calendar" => "/admin/calendar", "calendar day" => "/admin/calendar?day=#{today.iso8601}" }
  end

  def composers
    {
      "social mention" => lambda do
        visit "/admin/social"
        find("[data-social-body]").send_keys("@ada")
        find("[data-social-mentions]")
      end,
      "social targets" => lambda do
        connect_social_networks
        visit "/admin/social"
        find(".compose-target.bluesky:has(:checked)")
      end,
    }
  end

  def dialogs
    {
      "palette" => -> { open_palette },
      "person dialog" => -> { open_person_dialog },
      "task modal" => -> { open_modal },
      "task panel" => -> { open_panel },
    }
  end

  def journal_editors
    {
      "journal edit" => lambda do
        visit "/admin/journal"
        find(".journal-entry").click_button "Edit"
      end,
      "journal preview" => lambda do
        visit "/admin/journal"
        fill_in "Entry", with: "A **bold** line"
        find("#journal-entry .seg-option", text: "Preview").click
        find("#journal-entry .preview strong")
      end,
    }
  end

  def journal_entry
    @journal_entry ||= create(
      :journal_entry,
      body: "A **long** entry about the day and [everything](https://example.com/day) that went into it\n\n" \
            "- one\n- two\n\n```\n#{'a_very_long_line_of_code ' * 8}\n```",
      tags: %w[health commute ruby],
    )
  end

  def linked_records
    {
      "journal links" => "/admin/journal?to=#{journal_entry.entry_date.iso8601}&edit=#{journal_entry.id}",
      "work entry links" => "/admin/projects?filter=work&edit=#{work_entry.id}",
    }
  end

  def open_modal
    open_panel
    find("dialog#task-panel .btn", text: "Edit").click
    find("dialog#task-create[open] [data-task-edit]")
  end

  def open_palette
    visit "/admin"
    click_button(class: "slash")
    find("dialog#command-palette[open] [data-palette-query]:focus")
  end

  def open_panel
    visit "/admin/tasks?filter=next"
    find(".task-title", text: task.title).click
    find("dialog#task-panel[open] h1", text: task.title)
    settle("#task-panel")
  end

  def open_person_dialog
    visit "/admin/social"
    find("[data-social-body]").send_keys("@zed", :enter)
    find("dialog#person-dialog[open] form[data-person-form]")
  end

  def pages
    {
      "activity" => "/admin/activity",
      "analytics" => "/admin/analytics",
      "clients" => "/admin/clients",
      "commit" => "/admin/commits/#{commit.id}",
      "form expired" => lambda do
        visit "/admin/tags"
        forge_form "/admin/tags"
      end,
      "inbox" => "/admin/inbox",
      "journal" => "/admin/journal",
      "messages" => "/admin/messages",
      "new post" => "/admin/posts/new",
      "new project" => "/admin/projects/new",
      "not found" => "/admin/nothing-here",
      "post editor" => "/admin/posts/#{draft.id}/edit",
      "posts" => "/admin/posts",
      "project editor" => "/admin/projects/#{project.id}/edit",
      "projects" => "/admin/projects",
      "review" => "/admin/review",
      "review month" => "/admin/review?period=month",
      "search" => "/admin/search",
      "search results" => "/admin/search?q=accountant",
      "search by kind" => "/admin/search?q=quarterly&kind=task",
      "sign-in failed" => "/admin/auth/github/callback",
      "social" => "/admin/social",
      "social editor" => "/admin/social?edit=#{social_post.id}",
      "tags" => "/admin/tags",
      "task" => "/admin/tasks/#{task.id}",
      "task link search" => "/admin/tasks/#{task.id}?link_q=finished",
      "task editor" => "/admin/tasks/#{task.id}/edit",
      "tasks" => "/admin/tasks",
      "tasks archive" => "/admin/tasks?filter=completed",
      "tasks next" => "/admin/tasks?filter=next",
      "tasks someday" => "/admin/tasks?filter=someday",
      "time" => "/admin/time",
      "time by day" => "/admin/time?by=day",
      "today" => "/admin",
      "webmentions" => "/admin/webmentions",
    }
  end

  def people
    {
      "new person" => "/admin/people/new",
      "people" => "/admin/people",
      "person editor" => "/admin/people/#{person.id}/edit",
    }
  end

  def person = @person ||= create(:person, :bluesky, name: "Ada Lovelace", key: "ada-lovelace")

  def person_search
    {
      "person search" => lambda do
        connect_social_networks
        stub_bluesky_search("ada",
                            { avatar: "https://cdn.bsky.app/a.jpg", displayName: "Ada Lovelace",
                              handle: "ada.bsky.social" })
        visit "/admin/people/new"
        find_by_id("person-bluesky-search").send_keys("ada")
        find("#person-bluesky-results [role='option']", text: "Ada Lovelace")
      end,
    }
  end

  def record_search
    {
      "task record search" => "/admin/tasks/#{task.id}?record_q=published",
      "post record search" => "/admin/posts/#{draft.id}/edit?record_q=published",
    }
  end

  def saved_view_menus
    {
      "saved view menu" => lambda do
        visit "/admin/tasks"
        find(".saved-view", text: "Next up for the week").find("summary").click
        find(".saved-view-panel", visible: :visible)
      end,
      "save view in the rail" => lambda do
        visit "/admin/activity"
        find(".saved-views summary", text: "Save view").click
        find(".saved-view-panel", visible: :visible)
      end,
    }
  end

  def screens
    pages.merge(
      calendars, people, person_search, record_search, linked_records, composers, dialogs, journal_editors,
      saved_view_menus, selections, time_rows,
    )
  end

  def seed
    seed_analytics
    seed_calendar
    seed_tasks
    seed_writing
    seed_links
    create(:message, subject: "A question about the site")
    create(:saved_view, screen: "tasks", name: "Next up for the week", filters: { "filter" => "next" })
    create(:saved_view, screen: "activity", name: "Shipped this week", filters: { "q" => "ship" })
    create(:oauth_token, oauth_client: create(:oauth_client, client_name: "Claude"))
    person
  end

  def seed_analytics
    create(:analytics_rollup, day: today, views: 300, visitors: 210, read_seconds: 9_000)
    create(:analytics_rollup_path, day: today, path: "/writing/a-very-long-slug-for-a-post", views: 120)
    create(:analytics_rollup_referrer, day: today, host: "news.ycombinator.com", views: 60)
    create(:analytics_rollup_country, day: today, country_code: "US", views: 90)
  end

  def seed_calendar
    sprint = create(:sprint, sprint_date: today)
    create(:task, :in_sprint, sprint_id: sprint.id, title: "Plan the week ahead on the calendar screen")
    create(:task, :in_sprint, sprint_id: sprint.id, carried_count: 4, title: "A task that keeps slipping to tomorrow")
    create(:post, :published, title: "A post published today with a title too long to fit its cell",
                              published_at: at(0, 30))
    create(:social_post, :posted, posted_at: at(0, 45))
  end

  def seed_links
    link = Links::Slice["operations.link_records"]
    link.call("journal_entry", journal_entry.id, { other_kind: "post", other_id: draft.id })
    link.call("work_entry", work_entry.id, { other_kind: "project", other_id: project.id })
    link.call("social_post", social_post.id, { other_kind: "commit", other_id: commit.id })
  end

  def seed_tasks
    task
    create(:task_source, task:, url: "https://github.com/aaronmallen/aaronmallen.me/issues/42")
    running = create(:task, :in_progress, title: "Ship the phone layout")
    create(:task_link, from_task_id: task.id, to_task_id: running.id)
    Links::Slice["operations.link_records"].call("task", task.id, { other_kind: "commit", other_id: commit.id })
    create(:task, :done, title: "Something finished a while ago")
    seed_time
  end

  def seed_time
    timed = create(:task, :done, title: "Draw the time screen for a phone", worked_seconds: 3600, tags: %w[site])
    create(:work_session, task_id: timed.id, started_at: Time.now - 3660, ended_at: Time.now - 60)
    [project, create(:project, name: "a-second-project-with-a-long-name")].each do |linked|
      Links::Slice["operations.link_records"].call("task", timed.id, { other_kind: "project", other_id: linked.id })
    end
  end

  def seed_writing
    commit
    draft
    project
    create(:tag, name: "ruby", color: "mk-blue")
    create(
      :webmention, :reply,
      author_name: "Ada Lovelace",
      post: create(:post, :published, slug: "hello", title: "A published post with a fairly long title"),
    )
    social_post
    create(:post, :scheduled, title: "A post scheduled for tomorrow")
    create(:social_post, :scheduled)
  end

  def selections
    {
      "messages ticked" => -> { tick("/admin/messages", "input[name='ids[]']") },
      "posts ticked" => -> { tick("/admin/posts", "input[name='ids[]'][value='#{draft.id}']") },
      "tasks ticked" => -> { tick("/admin/tasks?filter=next", "input[name='ids[]'][value='#{task.id}']") },
      "webmentions ticked" => -> { tick("/admin/webmentions", "input[name='ids[]']") },
    }
  end

  def tick(path, box)
    visit path
    find(box).check
    find("[data-bulk-acts]")
  end

  def time_rows
    {
      "time row open" => lambda do
        visit "/admin/time"
        first(".time-row").click
        find(".time-group[open] .time-tasks")
      end,
    }
  end

  def work_entry = @work_entry ||= create(:work_entry, org: "Rackspace", role: "Software Engineer")

  before do
    seed
    connect_media_store
    sign_in_to_admin
  end

  it_behaves_like "accessible screens"
  it_behaves_like "readable screens", tap: true
end
