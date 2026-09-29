# frozen_string_literal: true

RSpec::Matchers.define_negated_matcher :not_include, :include

RSpec.describe "Translations", type: :request do
  %w[/ /writing /about /projects /contact /contact?sent=1].each do |path|
    it "renders #{path} without a missing translation" do
      get path

      expect(last_response.body).not_to include("translation_missing")
    end
  end

  {
    "every field blank" => { reply_to: "", subject: "", body: "" },
    "an address that is not one" => { reply_to: "ada", subject: "A question", body: "How?" },
    "a subject and a body over the cap" => { reply_to: "a" * 255, subject: "a" * 201, body: "a" * 5001 },
  }.each do |named, message|
    it "renders the contact form's errors for #{named} without a missing translation", :aggregate_failures do
      post "/contact", message: message

      expect(last_response.status).to eq(422)
      expect(last_response.body).not_to include("translation_missing")
    end
  end

  it "renders the contact throttle without a missing translation", :aggregate_failures do
    message = { reply_to: "ada@example.com", subject: "A question", body: "How?" }
    (Hanami.app["settings"].contact[:throttle_limit] + 1).times { post "/contact", message: message }

    expect(last_response.status).to eq(429)
    expect(last_response.body).not_to include("translation_missing")
  end

  describe "with projects and work entries" do
    before do
      create(:project, :featured)
      create(:project, :archived, archived_on: Blog::TimeZone.today)
      create(:project, release: nil, stars: 0, tagline: nil, url: nil)
      create(:work_entry)
      create(:work_entry, :current)
    end

    it "renders /projects without a missing translation", :aggregate_failures do
      get "/projects"

      expect(last_response).to be_ok
      expect(last_response.body).not_to include("translation_missing")
    end
  end

  describe "with published posts" do
    before do
      %w[older hello newer].each_with_index do |slug, index|
        create(:post, :published, slug:, tags: %w[ruby], published_at: Time.now - 3 + index)
      end
    end

    %w[/writing /writing/hello /writing/tags/ruby /writing.atom /writing/tags/ruby.atom].each do |path|
      it "renders #{path} without a missing translation", :aggregate_failures do
        get path

        expect(last_response).to be_ok
        expect(last_response.body).not_to include("translation_missing")
      end
    end
  end

  describe "an article with approved webmentions" do
    let(:types) { %i[reply mention like repost] }

    [1, 2].each do |count|
      it "renders #{count} of each type without a missing translation", :aggregate_failures do
        target = create(:post, :published, slug: "hello")
        types.each { |type| count.times { create(:webmention, :approved, type, post: target) } }
        get "/writing/hello"

        expect(last_response).to be_ok
        expect(last_response.body).not_to include("translation_missing")
      end
    end
  end

  describe "signed in with a post in each status" do
    let(:today) { Blog::TimeZone.today }

    before do
      create(:post, :draft)
      create(:post, :scheduled)
      create(:post, :published, tags: %w[ruby])
      create(:post, :published, slug: "hello", tags: %w[ruby])
      create(:analytics_rollup, day: today)
      create(:analytics_rollup_path, day: today, path: "/writing/hello", views: 1, visitors: 1, bounces: 1)
      sign_in_to_admin
    end

    %w[
      /admin /admin/posts /admin/posts/new /admin/clients /admin/tasks /admin/tasks?q=nothing
      /admin/tasks?filter=completed /admin/tags /admin/tags?q=nothing
    ].each do |path|
      it "renders #{path} without a missing translation", :aggregate_failures do
        get path

        expect(last_response).to be_ok
        expect(last_response.body).not_to include("translation_missing")
      end
    end
  end

  %i[draft scheduled published].each do |status|
    it "renders the editor for a #{status} post signed in without a missing translation", :aggregate_failures do
      post = create(:post, status, tags: %w[ruby])
      sign_in_to_admin
      get "/admin/posts/#{post.id}/edit"

      expect(last_response).to be_ok
      expect(last_response.body).not_to include("translation_missing")
    end
  end

  [0, 1, 2].each do |received|
    it "renders the editor's delete with #{received} webmentions without a missing translation" do
      article = create(:post, :published)
      received.times { create(:webmention, post: article) }
      sign_in_to_admin
      get "/admin/posts/#{article.id}/edit"

      expect(last_response.body).not_to include("translation_missing")
    end
  end

  describe "the tags screen" do
    let(:tag) { Tags::Slice["repos.tag_repo"].all.find { it.name == "ruby" } }

    before do
      create(:post, :published, tags: %w[ruby])
      sign_in_to_admin
    end

    {
      "added" => ["/admin/tags", { tag: { name: "hanami" } }],
      "renamed" => ["/admin/tags/%<id>s", { tag: { name: "rails" } }],
      "recoloured" => ["/admin/tags/%<id>s", { tag: { name: "ruby", color: "mk-sand" } }],
      "in use" => ["/admin/tags/%<id>s/delete", {}],
    }.each do |named, (path, params)|
      it "renders the #{named} toast without a missing translation" do
        post format(path, id: tag.id), { _csrf_token: admin_csrf_token, **params }
        follow_redirect!

        expect(last_response.body).to include("data-toast").and(not_include("translation_missing"))
      end
    end

    it "renders the removed toast without a missing translation" do
      Tags::Slice["operations.save_tag"].call({ name: "hanami" }, scope: "public")
      spare = Tags::Slice["repos.tag_repo"].all.find { it.name == "hanami" }
      post "/admin/tags/#{spare.id}/delete", _csrf_token: admin_csrf_token
      follow_redirect!

      expect(last_response.body).to include("data-toast").and(not_include("translation_missing"))
    end

    %w[public private].each do |scope|
      it "renders the #{scope} tab without a missing translation" do
        get("/admin/tags", scope:)

        expect(last_response.body).not_to include("translation_missing")
      end
    end

    it "renders every field error without a missing translation", :aggregate_failures do
      post "/admin/tags", _csrf_token: admin_csrf_token, tag: { name: "Machine Learning" }

      expect(last_response.status).to eq(422)
      expect(last_response.body).not_to include("translation_missing")
    end
  end

  it "renders the post delete toast without a missing translation" do
    article = create(:post, :published)
    sign_in_to_admin
    post "/admin/posts/#{article.id}/delete", _csrf_token: admin_csrf_token
    follow_redirect!

    expect(last_response.body).to include("data-toast").and(not_include("translation_missing"))
  end

  describe "the editor's suggestions" do
    let(:article) { create(:post, :draft, body: "word0 word1") }

    def decide(decision)
      post "/admin/posts/#{article.id}/suggestions/#{decision}", _csrf_token: admin_csrf_token
      follow_redirect!
    end

    def suggest(*originals)
      edits = originals.map { { original: it, replacement: "fixed", reason: "typo" } }

      Suggestions::Slice["repos.suggestion_repo"].replace_for_post(article.id, edits)
    end

    before { sign_in_to_admin }

    it "renders the card with a pending and a stale edit without a missing translation", :aggregate_failures do
      suggest("word0", "gone")
      get "/admin/posts/#{article.id}/edit"

      expect(last_response).to be_ok
      expect(last_response.body).not_to include("translation_missing")
    end

    [
      ["accept", %w[word0]],
      ["accept", %w[word0 word1]],
      ["reject", %w[word0]],
      ["reject", %w[word0 word1]],
    ].each do |decision, originals|
      it "renders the #{decision} toast for #{originals.size} without a missing translation" do
        suggest(*originals)
        decide(decision)

        expect(last_response.body).to include("data-toast").and(not_include("translation_missing"))
      end
    end

    it "renders the toast for edits that all went stale without a missing translation" do
      suggest("gone")
      decide("accept")

      expect(last_response.body).to include("data-toast").and(not_include("translation_missing"))
    end
  end

  [
    { title: "", slug: "Not a slug", tags: "a/b", publish_at: "2027-03-14T02:30" },
    { title: "Hello", slug: "tags", publish_at: "soon" },
    { title: "Hello", slug: "taken" },
  ].each do |fields|
    it "renders the editor's errors for #{fields} without a missing translation", :aggregate_failures do
      create(:post, slug: "taken")
      sign_in_to_admin
      post "/admin/posts", _csrf_token: admin_csrf_token, intent: "draft", post: fields

      expect(last_response.status).to eq(422)
      expect(last_response.body).not_to include("translation_missing")
    end
  end

  it "renders the editor's syndication error without a missing translation", :aggregate_failures do
    card = { syndication_enabled: "1", syndication_body: "a" * 301, syndication_targets: %w[bluesky] }
    sign_in_to_admin
    post "/admin/posts", _csrf_token: admin_csrf_token, intent: "publish", post: { title: "Hello", **card }

    expect(last_response.status).to eq(422)
    expect(last_response.body).not_to include("translation_missing")
  end

  [
    ["draft", ""],
    ["publish", "2030-01-01T09:00"],
    ["publish", ""],
  ].each do |intent, publish_at|
    it "renders the #{intent} toast for #{publish_at.inspect} without a missing translation", :aggregate_failures do
      sign_in_to_admin
      post "/admin/posts", _csrf_token: admin_csrf_token, intent:, post: { title: "Hello", publish_at: }
      follow_redirect!

      expect(last_response.body).to include("data-toast").and(not_include("translation_missing"))
    end
  end

  describe "signed in with journal entries" do
    before do
      create(:journal_entry, entry_date: Blog::TimeZone.today)
      create(:journal_entry, entry_date: Blog::TimeZone.today - 1)
      create(:journal_entry, entry_date: Blog::TimeZone.today - 5)
      sign_in_to_admin
    end

    [{}, { q: "zzz-nothing-matches" }].each do |params|
      it "renders /admin/journal with #{params} without a missing translation", :aggregate_failures do
        get "/admin/journal", params

        expect(last_response).to be_ok
        expect(last_response.body).not_to include("translation_missing")
      end
    end

    it "renders /admin without a missing translation", :aggregate_failures do
      get "/admin"

      expect(last_response).to be_ok
      expect(last_response.body).not_to include("translation_missing")
    end
  end

  it "renders the empty journal signed in without a missing translation", :aggregate_failures do
    sign_in_to_admin
    get "/admin/journal"

    expect(last_response).to be_ok
    expect(last_response.body).not_to include("translation_missing")
  end

  [
    { body: " ", entry_date: "soon" },
    { body: "walked", entry_date: "2999-01-01" },
    { body: "", entry_date: "2026-09-03" },
  ].each do |fields|
    it "renders the journal's errors for #{fields} without a missing translation", :aggregate_failures do
      sign_in_to_admin
      post "/admin/journal", _csrf_token: admin_csrf_token, entry: fields

      expect(last_response.status).to eq(422)
      expect(last_response.body).not_to include("translation_missing")
    end
  end

  it "renders the journal toast without a missing translation" do
    sign_in_to_admin
    post "/admin/journal", _csrf_token: admin_csrf_token, entry: { body: "walked" }
    follow_redirect!

    expect(last_response.body).to include("data-toast").and(not_include("translation_missing"))
  end

  it "renders a rejected entry on Today without a missing translation", :aggregate_failures do
    sign_in_to_admin
    post "/admin", _csrf_token: admin_csrf_token, entry: { body: " " }

    expect(last_response.status).to eq(422)
    expect(last_response.body).not_to include("translation_missing")
  end

  it "renders the Today journal toast without a missing translation" do
    sign_in_to_admin
    post "/admin", _csrf_token: admin_csrf_token, entry: { body: "walked" }
    follow_redirect!

    expect(last_response.body).to include("data-toast").and(not_include("translation_missing"))
  end

  it "renders a rejected journal edit without a missing translation", :aggregate_failures do
    entry = create(:journal_entry)
    sign_in_to_admin
    post "/admin/journal/#{entry.id}", _csrf_token: admin_csrf_token, entry: { body: " " }

    expect(last_response.status).to eq(422)
    expect(last_response.body).not_to include("translation_missing")
  end

  { "update" => "", "delete" => "/delete" }.each do |change, suffix|
    it "renders the journal #{change} toast without a missing translation" do
      entry = create(:journal_entry)
      sign_in_to_admin
      post "/admin/journal/#{entry.id}#{suffix}", _csrf_token: admin_csrf_token, entry: { body: "walked" }
      follow_redirect!

      expect(last_response.body).to include("data-toast").and(not_include("translation_missing"))
    end
  end

  it "renders the preview without a missing translation", :aggregate_failures do
    sign_in_to_admin
    post "/admin/posts/preview", _csrf_token: admin_csrf_token, post: { title: "Hello", tags: "ruby", body: "one" }

    expect(last_response).to be_ok
    expect(last_response.body).not_to include("translation_missing")
  end

  describe "signed in with a project in each status" do
    before do
      Blog::Types::ProjectStatus.each_value { create(:project, status: it) }
      create(:project, :featured)
      create(:project, :archived, archived_on: Blog::TimeZone.today)
      sign_in_to_admin
    end

    %w[live archived].each do |filter|
      it "renders /admin/projects filtered by #{filter} without a missing translation", :aggregate_failures do
        get "/admin/projects", filter: filter

        expect(last_response).to be_ok
        expect(last_response.body).not_to include("translation_missing")
      end
    end
  end

  %w[live archived work].each do |filter|
    it "renders the empty /admin/projects for #{filter} without a missing translation", :aggregate_failures do
      sign_in_to_admin
      get "/admin/projects", filter: filter

      expect(last_response).to be_ok
      expect(last_response.body).not_to include("translation_missing")
    end
  end

  describe "the work history tab" do
    before do
      create(:work_entry)
      create(:work_entry, :current)
      create(:work_entry, blurb: nil)
      sign_in_to_admin
    end

    it "renders /admin/projects filtered by work without a missing translation", :aggregate_failures do
      get "/admin/projects", filter: "work"

      expect(last_response).to be_ok
      expect(last_response.body).not_to include("translation_missing")
    end
  end

  [
    { org: " ", role: " " },
    { org: "Rackspace", role: "Engineer", from_year: "" },
    { org: "Rackspace", role: "Engineer", from_year: "18", to_year: "21" },
    { org: "Rackspace", role: "Engineer", from_year: "2021", to_year: "2018" },
  ].each do |work_entry|
    it "renders the work form's errors for #{work_entry} without a missing translation", :aggregate_failures do
      sign_in_to_admin
      post "/admin/projects/work", _csrf_token: admin_csrf_token, work_entry: work_entry

      expect(last_response.status).to eq(422)
      expect(last_response.body).not_to include("translation_missing")
    end
  end

  it "renders the role added toast without a missing translation" do
    role = { org: "Rackspace", role: "Engineer", from_year: "2018" }
    sign_in_to_admin
    post "/admin/projects/work", _csrf_token: admin_csrf_token, work_entry: role
    follow_redirect!

    expect(last_response.body).to include("data-toast").and(not_include("translation_missing"))
  end

  it "renders the role removed toast without a missing translation" do
    entry = create(:work_entry)
    sign_in_to_admin
    post "/admin/projects/work/#{entry.id}/delete", _csrf_token: admin_csrf_token
    follow_redirect!

    expect(last_response.body).to include("data-toast").and(not_include("translation_missing"))
  end

  it "renders /admin/projects/new without a missing translation", :aggregate_failures do
    sign_in_to_admin
    get "/admin/projects/new"

    expect(last_response).to be_ok
    expect(last_response.body).not_to include("translation_missing")
  end

  %i[active wip paused archived].each do |status|
    it "renders the editor for a #{status} project without a missing translation", :aggregate_failures do
      project = status == :archived ? create(:project, :archived) : create(:project, status: status.to_s)
      sign_in_to_admin
      get "/admin/projects/#{project.id}/edit"

      expect(last_response).to be_ok
      expect(last_response.body).not_to include("translation_missing")
    end
  end

  it "renders the editor for a bare project without a missing translation", :aggregate_failures do
    bare = { release: nil, repo: nil, started_on: nil, tagline: nil, url: nil }
    sign_in_to_admin
    get "/admin/projects/#{create(:project, **bare).id}/edit"

    expect(last_response).to be_ok
    expect(last_response.body).not_to include("translation_missing")
  end

  [
    { name: "  " },
    { name: "sai", repo: "Not a repo", url: "https://example.com/sai" },
    { name: "sai", repo: "aaronmallen/gest", url: "gest.aaronmallen.dev" },
    { name: "sai", status: "archived", started_on: "June", tags: "a/b" },
    { name: "sai", started_on: "2999-01" },
  ].each do |fields|
    it "renders the project editor's errors for #{fields} without a missing translation", :aggregate_failures do
      sign_in_to_admin
      post "/admin/projects", _csrf_token: admin_csrf_token, project: fields

      expect(last_response.status).to eq(422)
      expect(last_response.body).not_to include("translation_missing")
    end
  end

  it "renders the project created toast without a missing translation" do
    sign_in_to_admin
    post "/admin/projects", _csrf_token: admin_csrf_token, project: { name: "sai", repo: "aaronmallen/sai" }
    follow_redirect!

    expect(last_response.body).to include("data-toast").and(not_include("translation_missing"))
  end

  it "renders the project not started toast without a missing translation" do
    id = create(:project, started_on: Blog::TimeZone.today.next_month).id
    sign_in_to_admin
    post "/admin/projects/#{id}/archive", _csrf_token: admin_csrf_token
    follow_redirect!

    expect(last_response.body).to include("data-toast").and(not_include("translation_missing"))
  end

  it "renders the project saved toast without a missing translation" do
    id = create(:project, repo: "aaronmallen/sai").id
    sign_in_to_admin
    post "/admin/projects/#{id}", _csrf_token: admin_csrf_token, project: { name: "sai", repo: "aaronmallen/sai" }
    follow_redirect!

    expect(last_response.body).to include("data-toast").and(not_include("translation_missing"))
  end

  describe "reordering the projects" do
    let!(:middle) { create(:project, position: 2) }

    before do
      create(:project, position: 1)
      create(:project, position: 3)
      sign_in_to_admin
    end

    %w[up down].each do |direction|
      it "renders /admin/projects after moving #{direction} without a missing translation", :aggregate_failures do
        post "/admin/projects/#{middle.id}/move/#{direction}", _csrf_token: admin_csrf_token
        follow_redirect!

        expect(last_response).to be_ok
        expect(last_response.body).not_to include("translation_missing")
      end
    end
  end

  { "archive" => :project, "restore" => %i[project archived] }.each do |change, traits|
    it "renders the project #{change} toast without a missing translation" do
      project = create(*Array(traits))
      sign_in_to_admin
      post "/admin/projects/#{project.id}/#{change}", _csrf_token: admin_csrf_token
      follow_redirect!

      expect(last_response.body).to include("data-toast").and(not_include("translation_missing"))
    end
  end

  describe "signed in with a message in each status" do
    before do
      create(:message)
      create(:message, :read)
      create(:message, :spam)
      sign_in_to_admin
    end

    %w[unread read spam].each do |status|
      it "renders /admin/messages filtered by #{status} without a missing translation", :aggregate_failures do
        get "/admin/messages", status: status

        expect(last_response).to be_ok
        expect(last_response.body).not_to include("translation_missing")
      end
    end
  end

  %w[unread read spam].each do |status|
    it "renders the empty /admin/messages for #{status} without a missing translation", :aggregate_failures do
      sign_in_to_admin
      get "/admin/messages", status: status

      expect(last_response).to be_ok
      expect(last_response.body).not_to include("translation_missing")
    end
  end

  %w[read spam unread].each do |status|
    it "renders the message #{status} toast without a missing translation" do
      message = create(:message, :read)
      sign_in_to_admin
      post "/admin/messages/#{message.id}/mark/#{status}", _csrf_token: admin_csrf_token
      follow_redirect!

      expect(last_response.body).to include("data-toast").and(not_include("translation_missing"))
    end
  end

  describe "signed in with a webmention in each status" do
    let(:target) { create(:post, :published) }

    before do
      create(:webmention, :reply, post: target)
      create(:webmention, :like, :approved, post: target)
      create(:webmention, :repost, :spam, post: target)
      sign_in_to_admin
    end

    %w[pending approved spam].each do |status|
      it "renders /admin/webmentions filtered by #{status} without a missing translation", :aggregate_failures do
        get "/admin/webmentions", status: status

        expect(last_response).to be_ok
        expect(last_response.body).not_to include("translation_missing")
      end
    end

    %w[/admin /admin/analytics].each do |path|
      it "renders #{path} with a pending mention without a missing translation", :aggregate_failures do
        get path

        expect(last_response).to be_ok
        expect(last_response.body).not_to include("translation_missing")
      end
    end
  end

  %w[pending approved spam].each do |status|
    it "renders the empty /admin/webmentions for #{status} without a missing translation", :aggregate_failures do
      sign_in_to_admin
      get "/admin/webmentions", status: status

      expect(last_response).to be_ok
      expect(last_response.body).not_to include("translation_missing")
    end
  end

  %w[approve spam].each do |change|
    it "renders the webmention #{change} toast without a missing translation" do
      mention = create(:webmention, post: create(:post, :published))
      sign_in_to_admin
      post "/admin/webmentions/#{mention.id}/#{change}", _csrf_token: admin_csrf_token
      follow_redirect!

      expect(last_response.body).to include("data-toast").and(not_include("translation_missing"))
    end
  end

  it "renders the webmention settings toast without a missing translation" do
    sign_in_to_admin
    post "/admin/webmentions/settings", _csrf_token: admin_csrf_token, settings: { receive: "0" }
    follow_redirect!

    expect(last_response.body).to include("data-toast").and(not_include("translation_missing"))
  end

  describe "signed in with analytics" do
    before do
      create(:analytics_rollup, day: Blog::TimeZone.today - 1, views: 1204, visitors: 759, read_seconds: 9_000)
      create(:analytics_rollup, day: Blog::TimeZone.today - 9, views: 90, visitors: 60, read_seconds: 600)
      create(:analytics_rollup_path, day: Blog::TimeZone.today - 1, path: "/writing/hello", title: "Hello")
      create(:analytics_rollup_referrer, day: Blog::TimeZone.today - 1)
      create(:analytics_rollup_referrer, :direct, day: Blog::TimeZone.today - 1)
      create(:analytics_rollup_country, day: Blog::TimeZone.today - 1)
      create(:analytics_rollup_country, :unknown, day: Blog::TimeZone.today - 1)
      create(:analytics_event)
      sign_in_to_admin
    end

    %w[7 14 30].each do |range|
      it "renders /admin/analytics over #{range} days without a missing translation", :aggregate_failures do
        get "/admin/analytics", range: range

        expect(last_response).to be_ok
        expect(last_response.body).not_to include("translation_missing")
      end
    end
  end

  it "renders the empty /admin/analytics without a missing translation", :aggregate_failures do
    sign_in_to_admin
    get "/admin/analytics"

    expect(last_response).to be_ok
    expect(last_response.body).not_to include("translation_missing")
  end

  describe "signed in with activity of every type" do
    let(:today) { Blog::TimeZone.today }

    def at(hour, on: today) = Blog::TimeZone.local_time(on.year, on.month, on.day, hour, 0)

    before do
      target = create(:post, :published, slug: "hello", published_at: at(9))
      create(:social_post, :posted, posted_at: at(12))
      create(:webmention, post: target, received_at: at(8))
      create(:commit, commit_date: today)
      create(:journal_entry, entry_date: today - 3)
      create(:task, :done, completed_at: at(16))
      create(:project)
      create(:sprint, sprint_date: today)
      Suggestions::Slice["repos.suggestion_repo"]
        .replace_for_post(target.id, [{ original: "teh", replacement: "the", reason: "typo" }])
      sign_in_to_admin
    end

    [{}, { from: "2026-01-01" }, { q: "zzz-nothing-matches" }, { q: "repo:aaronmallen/none" }].each do |params|
      it "renders /admin/activity with #{params} without a missing translation", :aggregate_failures do
        get "/admin/activity", params

        expect(last_response).to be_ok
        expect(last_response.body).not_to include("translation_missing")
      end
    end
  end

  it "renders the empty /admin/activity without a missing translation", :aggregate_failures do
    sign_in_to_admin
    get "/admin/activity"

    expect(last_response).to be_ok
    expect(last_response.body).not_to include("translation_missing")
  end

  { "a subject alone" => "subject only", "a body" => "subject\n\nwith a body" }.each do |named, message|
    it "renders a commit with #{named} without a missing translation", :aggregate_failures do
      commit = create(:commit, commit_date: Blog::TimeZone.today, message:)
      sign_in_to_admin
      get "/admin/commits/#{commit.id}"

      expect(last_response).to be_ok
      expect(last_response.body).not_to include("translation_missing")
    end
  end

  describe "the social composer" do
    before do
      connect_social_networks
      sign_in_to_admin
    end

    def compose(intent: "send", **params)
      post "/admin/social", _csrf_token: admin_csrf_token, intent:,
                            social: { parts: ["hello"], targets: %w[mastodon bluesky], **params }
    end

    it "renders /admin/social without a missing translation", :aggregate_failures do
      create(:social_post, :scheduled)
      get "/admin/social"

      expect(last_response).to be_ok
      expect(last_response.body).not_to include("translation_missing")
    end

    [
      { parts: ["  "] },
      { targets: [] },
      { parts: ["a" * 501] },
      { mode: "schedule", schedule_at: "soon" },
      { mode: "schedule", schedule_at: "2027-03-14T02:30" },
    ].each do |fields|
      it "renders the composer's errors for #{fields} without a missing translation", :aggregate_failures do
        compose(**fields)

        expect(last_response.status).to eq(422)
        expect(last_response.body).not_to include("translation_missing")
      end
    end

    [
      ["send", {}],
      ["send", { mode: "schedule", schedule_at: "2030-01-01T09:00" }],
      ["draft", {}],
    ].each do |intent, fields|
      it "renders the #{intent} toast for #{fields} without a missing translation", :aggregate_failures do
        compose(intent:, **fields)
        follow_redirect!

        expect(last_response.body).to include("data-toast").and(not_include("translation_missing"))
      end
    end
  end

  describe "the social queue" do
    before do
      connect_social_networks
      sign_in_to_admin
    end

    def fill_the_queue
      posted = create(:social_post, :posted)
      create(:social_post_delivery, :mastodon, social_post_id: posted.id, error: "rate limited")
      create(:social_post, :scheduled, posted_at: Time.now + (26 * 60 * 60))
      create(:social_post, :draft)
    end

    %w[queued posted drafts].each do |filter|
      it "renders the empty /admin/social for #{filter} without a missing translation", :aggregate_failures do
        get "/admin/social", filter: filter

        expect(last_response).to be_ok
        expect(last_response.body).not_to include("translation_missing")
      end

      it "renders /admin/social for #{filter} with items without a missing translation", :aggregate_failures do
        fill_the_queue
        get "/admin/social", filter: filter

        expect(last_response).to be_ok
        expect(last_response.body).not_to include("translation_missing")
      end
    end

    it "renders /admin with a scheduled social post without a missing translation", :aggregate_failures do
      create(:social_post, :scheduled)
      get "/admin"

      expect(last_response).to be_ok
      expect(last_response.body).not_to include("translation_missing")
    end

    it "renders a queued item in the composer without a missing translation", :aggregate_failures do
      social_post = create(:social_post, :scheduled)
      get "/admin/social", edit: social_post.id

      expect(last_response).to be_ok
      expect(last_response.body).not_to include("translation_missing")
    end

    it "renders the removed toast without a missing translation" do
      social_post = create(:social_post, :draft)
      post "/admin/social/#{social_post.id}/delete", _csrf_token: admin_csrf_token, filter: "drafts"
      follow_redirect!

      expect(last_response.body).to include("data-toast").and(not_include("translation_missing"))
    end
  end

  it "renders /admin/social with no network connected without a missing translation", :aggregate_failures do
    connect_social_networks(bluesky: {}, mastodon: {})
    sign_in_to_admin
    get "/admin/social"

    expect(last_response).to be_ok
    expect(last_response.body).not_to include("translation_missing")
  end

  it "renders the saved toast without a missing translation" do
    published = create(:post, :published, slug: "hello")
    sign_in_to_admin
    post "/admin/posts/#{published.id}", _csrf_token: admin_csrf_token, intent: "save", post: { title: "Hello" }
    follow_redirect!

    expect(last_response.body).to include("data-toast").and(not_include("translation_missing"))
  end

  describe "the MCP clients page" do
    let(:mcp) { Spec::DB::Factories[:mcp] }

    before { sign_in_to_admin }

    { "never used" => nil, "used before" => Time.at(0) }.each do |label, used|
      it "renders /admin/clients #{label} without a missing translation", :aggregate_failures do
        mcp.create(:oauth_client, last_used_at: used)
        get "/admin/clients"

        expect(last_response).to be_ok
        expect(last_response.body).not_to include("translation_missing")
      end
    end

    it "renders the revoke toast without a missing translation" do
      client = mcp.create(:oauth_client)
      post "/admin/clients/#{client.id}/revoke", _csrf_token: admin_csrf_token
      follow_redirect!

      expect(last_response.body).to include("data-toast").and(not_include("translation_missing"))
    end
  end

  describe "the MCP authorization prompt" do
    let(:client) { Spec::DB::Factories[:mcp].create(:oauth_client) }
    let(:verifier) { MCP::OAuth::Secret.generate }

    def authorize_path
      params = {
        client_id: client.client_id,
        code_challenge: MCP::OAuth::PKCE.challenge(verifier),
        code_challenge_method: "S256",
        redirect_uri: client.redirect_uris.first,
        response_type: "code",
        scope: MCP::OAuth::Scope::ALL.join(" "),
        state: "state-from-claude",
      }

      "/oauth/authorize?#{Rack::Utils.build_query(params)}"
    end

    before { sign_in_to_admin }

    it "renders /oauth/authorize without a missing translation", :aggregate_failures do
      get authorize_path

      expect(last_response).to be_ok
      expect(last_response.body).not_to include("translation_missing")
    end

    it "renders the expired form without a missing translation", :aggregate_failures do
      get authorize_path
      post "/oauth/authorize", authorization_fields.merge("_csrf_token" => "forged", "decision" => "approve")

      expect(last_response.status).to eq(403)
      expect(last_response.body).not_to include("translation_missing")
    end
  end

  describe "with tasks in every list" do
    let(:task) { Tasks::Slice["repos.task_repo"].in_list("next").first }

    before do
      sprint = create(:sprint, sprint_date: Blog::TimeZone.today)
      create(:task, :in_sprint, sprint_id: sprint.id)
      create(:task, :carried, :in_progress, :in_sprint, sprint_id: sprint.id)
      create(:task, :in_sprint, sprint: create(:sprint, sprint_date: Blog::TimeZone.today + 1))
      create(:task, :done)
      create(:task)
      create(:task, :someday)
      sign_in_to_admin
    end

    %w[
      /admin/tasks /admin/tasks?filter=today /admin/tasks?filter=upcoming /admin/tasks?filter=next
      /admin/tasks?filter=someday /admin/tasks?filter=completed /admin/tasks?filter=completed&q=nothing
      /admin/tasks?filter=next&q=nothing
    ].each do |path|
      it "renders #{path} without a missing translation", :aggregate_failures do
        get path

        expect(last_response).to be_ok
        expect(last_response.body).not_to include("translation_missing")
      end
    end

    it "renders the capture error without a missing translation", :aggregate_failures do
      post "/admin/tasks", _csrf_token: admin_csrf_token, filter: "next", task: { title: " " }

      expect(last_response.status).to eq(422)
      expect(last_response.body).not_to include("translation_missing")
    end

    it "renders the editor errors without a missing translation", :aggregate_failures do
      fields = { title: " ", list: "later", tags: "a b/c" }
      post "/admin/tasks/#{task.id}", _csrf_token: admin_csrf_token, filter: "next", task: fields

      expect(last_response.status).to eq(422)
      expect(last_response.body).not_to include("translation_missing")
    end

    {
      "" => { task: { title: "Renamed" } },
      "/complete" => {},
      "/delete" => {},
      "/move/someday" => {},
      "/reopen" => {},
      "/start" => {},
      "/stop" => {},
    }.each do |suffix, params|
      it "renders the toast for POST /admin/tasks/:id#{suffix} without a missing translation" do
        post "/admin/tasks/#{task.id}#{suffix}", { _csrf_token: admin_csrf_token, **params }
        follow_redirect!

        expect(last_response.body).to include("data-toast").and(not_include("translation_missing"))
      end
    end

    it "renders a refused task from Today without a missing translation" do
      post "/admin/tasks", _csrf_token: admin_csrf_token, origin: "today", task: { title: " ", list: "today" }

      expect(last_response.body).to include("field-error").and(not_include("translation_missing"))
    end

    it "renders the new task page from Today without a missing translation" do
      get "/admin/tasks/new", origin: "today"

      expect(last_response.body).not_to include("translation_missing")
    end

    {
      "a day ahead" => -> { (Blog::TimeZone.today + 2).iso8601 },
      "today" => -> { Blog::TimeZone.today.iso8601 },
      "no day at all" => -> { "" },
      "a day it cannot read" => -> { "yesterday" },
    }.each do |named, asked|
      it "renders the schedule toast for #{named} without a missing translation" do
        post "/admin/tasks/#{task.id}/schedule", _csrf_token: admin_csrf_token, sprint_on: instance_exec(&asked)
        follow_redirect!

        expect(last_response.body).to include("data-toast").and(not_include("translation_missing"))
      end
    end
  end

  describe "planning sprints" do
    let(:tomorrow) { Blog::TimeZone.today + 1 }

    before { sign_in_to_admin }

    def plan(asked)
      post "/admin/tasks/sprints", _csrf_token: admin_csrf_token, sprint_on: asked
      follow_redirect!
    end

    {
      "plans one" => -> { tomorrow.iso8601 },
      "refuses a day that is over" => -> { (Blog::TimeZone.today - 1).iso8601 },
      "refuses today" => -> { Blog::TimeZone.today.iso8601 },
      "refuses a date it cannot read" => -> { "soon" },
    }.each do |named, asked|
      it "renders the toast when planning #{named} without a missing translation" do
        plan(instance_exec(&asked))

        expect(last_response.body).to include("data-toast").and(not_include("translation_missing"))
      end
    end

    it "renders the toast when planning refuses a day that already has one" do
      create(:sprint, sprint_date: tomorrow)
      plan(tomorrow.iso8601)

      expect(last_response.body).to include("data-toast").and(not_include("translation_missing"))
    end

    {
      "drops one" => 1,
      "refuses the running one" => 0,
    }.each do |named, days|
      it "renders the toast when dropping #{named} without a missing translation" do
        sprint = create(:sprint, sprint_date: Blog::TimeZone.today + days)
        post "/admin/tasks/sprints/#{sprint.id}/delete", _csrf_token: admin_csrf_token
        follow_redirect!

        expect(last_response.body).to include("data-toast").and(not_include("translation_missing"))
      end
    end
  end

  describe "with an empty sprint" do
    before { sign_in_to_admin }

    %w[
      /admin /admin?pool=someday /admin/tasks?filter=today /admin/tasks?filter=today&pool=someday
    ].each do |path|
      it "renders the planner on #{path} without a missing translation", :aggregate_failures do
        create(:task)
        create(:task, :someday)
        get path

        expect(last_response).to be_ok
        expect(last_response.body).not_to include("translation_missing")
      end

      it "renders the planner on #{path} with both pools empty", :aggregate_failures do
        get path

        expect(last_response).to be_ok
        expect(last_response.body).not_to include("translation_missing")
      end
    end
  end

  describe "the date and time formats" do
    let(:date) { Date.new(2026, 9, 4) }
    let(:time) { Blog::TimeZone.local(Time.utc(2026, 9, 8, 2, 30)) }

    {
      full: "Friday, September 4, 2026",
      long: "September 4, 2026",
      medium: "Sep 4, 2026",
      short: "Sep 4",
      weekday: "Friday, September 4",
    }.each do |format, text|
      it "reads a date in the #{format} format as #{text}" do
        expect(Admin::Slice["i18n"].l(date, format:)).to eq(text)
      end
    end

    { clock: "21:30", medium: "Sep 7, 2026, 21:30" }.each do |format, text|
      it "reads a Chicago time in the #{format} format as #{text}" do
        expect(Admin::Slice["i18n"].l(time, format:)).to eq(text)
      end
    end

    it "reads a date the same on the public site" do
      expect(Public::Slice["i18n"].l(date, format: :medium)).to eq("Sep 4, 2026")
    end
  end
end
