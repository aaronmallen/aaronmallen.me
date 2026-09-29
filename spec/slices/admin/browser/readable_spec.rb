# frozen_string_literal: true

RSpec.describe "Admin screens", type: :feature do
  let(:commit) { create(:commit, message: "app: make the admin usable on a phone", repo: "aaronmallen/blog") }
  let(:draft) { create(:post, :draft, title: "A draft in progress") }
  let(:project) { create(:project, name: "aaronmallen.me", tagline: "This website") }
  let(:social_post) { create(:social_post, :draft) }
  let(:task) { create(:task, title: "Email the accountant about the quarterly filing") }

  def screens
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
      "task links" => "/admin/tasks?link=#{task.id}",
      "tasks" => "/admin/tasks",
      "tasks archive" => "/admin/tasks?filter=completed",
      "tasks next" => "/admin/tasks?filter=next",
      "tasks someday" => "/admin/tasks?filter=someday",
      "today" => "/admin",
      "webmentions" => "/admin/webmentions",
    }
  end

  def seed
    seed_analytics
    seed_tasks
    seed_writing
    create(:journal_entry, body: "A long entry about the day and everything that went into it")
    create(:message, subject: "A question about the site")
    create(:oauth_token, oauth_client: create(:oauth_client, client_name: "Claude"))
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
    create(:task, :in_progress, title: "Ship the phone layout")
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
    sign_in_to_admin
  end

  it_behaves_like "accessible screens"
  it_behaves_like "readable screens", tap: true
end
