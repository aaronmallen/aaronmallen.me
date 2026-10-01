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

  def composers
    {
      "social mention" => lambda do
        visit "/admin/social"
        find("[data-social-body]").send_keys("@ada")
        find("[data-social-mentions]")
      end,
    }
  end

  def dialogs = { "task modal" => -> { open_modal }, "task panel" => -> { open_panel } }

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

  def open_modal
    open_panel
    find("dialog#task-panel .btn", text: "Edit").click
    find("dialog#task-create[open] [data-task-edit]")
  end

  def open_panel
    visit "/admin/tasks?filter=next"
    find(".task-title", text: task.title).click
    find("dialog#task-panel[open] h1", text: task.title)
    settle("#task-panel")
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
      "journal" => "/admin/journal",
      "messages" => "/admin/messages",
      "new post" => "/admin/posts/new",
      "new project" => "/admin/projects/new",
      "not found" => "/admin/nothing-here",
      "post editor" => "/admin/posts/#{draft.id}/edit",
      "posts" => "/admin/posts",
      "project editor" => "/admin/projects/#{project.id}/edit",
      "projects" => "/admin/projects",
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

  def screens = pages.merge(people, composers, dialogs, journal_editors)

  def seed
    seed_analytics
    seed_tasks
    seed_writing
    create(
      :journal_entry,
      body: "A **long** entry about the day and [everything](https://example.com/day) that went into it\n\n" \
            "- one\n- two\n\n```\n#{'a_very_long_line_of_code ' * 8}\n```",
      tags: %w[health commute ruby],
    )
    create(:message, subject: "A question about the site")
    create(:oauth_token, oauth_client: create(:oauth_client, client_name: "Claude"))
    person
  end

  def seed_analytics
    today = Blog::TimeZone.today
    create(:analytics_rollup, day: today, views: 300, visitors: 210, read_seconds: 9_000)
    create(:analytics_rollup_path, day: today, path: "/writing/a-very-long-slug-for-a-post", views: 120)
    create(:analytics_rollup_referrer, day: today, host: "news.ycombinator.com", views: 60)
    create(:analytics_rollup_country, day: today, country_code: "US", views: 90)
  end

  def seed_tasks
    task
    create(:task_source, task:, url: "https://github.com/aaronmallen/aaronmallen.me/issues/42")
    running = create(:task, :in_progress, title: "Ship the phone layout")
    create(:task_link, from_task_id: task.id, to_task_id: running.id)
    create(:task, :done, title: "Something finished a while ago")
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
  end

  before do
    seed
    connect_media_store
    sign_in_to_admin
  end

  it_behaves_like "accessible screens"
  it_behaves_like "readable screens", tap: true
end
