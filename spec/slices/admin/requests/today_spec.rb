# frozen_string_literal: true

RSpec.describe "Admin today", type: :request do
  let(:page) { Capybara.string(last_response.body) }
  let(:i18n) { Admin::Slice["i18n"] }
  let(:repo) { Record::Slice["repos.journal_entry_repo"] }
  let(:today) { Blog::TimeZone.today }
  let(:toast) { page.find("[data-toast] .toast", visible: :all).text(:all) }

  def card(title) = page.find(".g-2 > .side-stack > section.card", text: title)

  def column(position) = page.all(".g-2 > .side-stack")[position]

  def commit_repo = Record::Slice["repos.commit_repo"]

  def commit_row = commits_card.find(".commits .commit")

  def commits_card = card("Commits imported today")

  def commits_stat = page.find(".g-4 .stat", text: "Commits")

  def create_commit(**attributes) = create(:commit, **attributes)

  def create_detailed_commit
    create_commit(
      sha: "9f8e7d6c5b4a39281706f5e4d3c2b1a098765432", repo: "aaronmallen/blog", commit_date: today,
      commit_time: "14:05", message: "admin: add the commits card", additions: 120, deletions: 8,
    )
  end

  def create_entry(**attributes) = create(:journal_entry, **attributes)

  def journaled_stat = page.find(".g-4 .stat", text: "Journaled")

  def pending_card = card("Webmentions pending")

  def queue_stat = page.find(".g-4 .stat", text: "In the queue")

  def save(**fields)
    post "/admin", _csrf_token: admin_csrf_token, entry: fields
  end

  def schedule_social(*parts, at: Time.now + 60, targets: %w[mastodon])
    Social::Slice["repos.social_post_repo"].create_with_parts(targets:, status: "scheduled", posted_at: at, parts:)
  end

  def titles(title) = card(title).all(".li-title").map(&:text)

  def webmentions_stat = page.find(".g-4 .stat", text: "Webmentions")

  def with_token
    connect_github(client_id: "client-id", client_secret: "client-secret", api_token: "ghp_token")
  end

  describe "signed in" do
    before { sign_in_to_admin }

    it "puts the journal and commit cards on the left and the post cards on the right", :aggregate_failures do
      get "/admin"

      expect(column(0).all("h2.card-title").map(&:text))
        .to eq(["Journal", "Commits imported today"])
      expect(column(1).all("h2.card-title").map(&:text)).to eq(["What ships next", "Drafts"])
    end

    describe "What ships next" do
      it "lists scheduled posts, soonest first" do
        create(:post, :scheduled, title: "Later", published_at: Time.now + 120)
        create(:post, :scheduled, title: "Sooner", published_at: Time.now + 60)
        get "/admin"

        expect(titles("What ships next")).to eq(%w[Sooner Later])
      end

      it "leaves out drafts and published posts" do
        create(:post, :draft, title: "Draft")
        create(:post, :published, title: "Published")
        get "/admin"

        expect(titles("What ships next")).to be_empty
      end

      it "links each row to its editor" do
        post = create(:post, :scheduled, title: "Linked")
        get "/admin"

        expect(card("What ships next")).to have_link("Linked", href: "/admin/posts/#{post.id}/edit", class: "li-title")
      end

      it "shows the Chicago publish time under the title" do
        create(:post, :scheduled, published_at: Time.utc(2030, 1, 7, 15, 30))
        get "/admin"

        expect(card("What ships next")).to have_css(".li-sub", exact_text: "Jan 7, 2030, 09:30")
      end

      it "shows an empty state without scheduled posts" do
        get "/admin"

        expect(card("What ships next")).to have_css(".empty", exact_text: i18n.t("ui.components.ships_next_card.empty"))
      end

      it "lists scheduled social posts after the blog posts" do
        create(:post, :scheduled, title: "Blog", published_at: Time.now + 600)
        schedule_social("Social")
        get "/admin"

        expect(titles("What ships next")).to eq(%w[Blog Social])
      end

      it "lists scheduled social posts soonest first" do
        schedule_social("Later", at: Time.now + 120)
        schedule_social("Sooner", at: Time.now + 60)
        get "/admin"

        expect(titles("What ships next")).to eq(%w[Sooner Later])
      end

      it "leaves out drafted and posted social posts" do
        create(:social_post, :draft)
        create(:social_post, :posted)
        get "/admin"

        expect(card("What ships next")).to have_css(".empty")
      end

      it "opens the queue on the queued filter from a social row" do
        schedule_social("Social")
        get "/admin"

        expect(card("What ships next"))
          .to have_link("Social", href: "/admin/social?filter=queued", class: "li-title")
      end

      it "puts the Chicago time and the networks under a social post" do
        schedule_social("Social", at: Time.utc(2030, 1, 7, 15, 30), targets: %w[mastodon bluesky])
        get "/admin"

        expect(card("What ships next"))
          .to have_css(".li-sub", exact_text: "Jan 7, 2030, 09:30 · Mastodon + Bluesky")
      end

      it "shortens a long social post to one line" do
        schedule_social("#{'word ' * 20}end")
        get "/admin"

        expect(titles("What ships next")).to eq(["#{('word ' * 12).strip}…"])
      end

      it "reads a threaded social post by its first part" do
        schedule_social("First", "Second")
        get "/admin"

        expect(titles("What ships next")).to eq(%w[First])
      end

      it "keeps a social post with line breaks on one line" do
        schedule_social("First\n\nSecond")
        get "/admin"

        expect(titles("What ships next")).to eq(["First Second"])
      end
    end

    describe "the In the queue stat" do
      it "counts scheduled blog posts and scheduled social posts together", :aggregate_failures do
        create(:post, :scheduled, published_at: Time.now + 600)
        schedule_social("Social")
        get "/admin"

        expect(queue_stat).to have_css(".stat-key", exact_text: "In the queue")
        expect(queue_stat).to have_css(".stat-value", exact_text: "2")
      end

      it "leaves out drafts and published posts" do
        create(:post, :draft)
        create(:post, :published)
        get "/admin"

        expect(queue_stat).to have_css(".stat-value", exact_text: "0")
      end

      it "leaves out drafted and posted social posts" do
        create(:social_post, :draft)
        create(:social_post, :posted)
        get "/admin"

        expect(queue_stat).to have_css(".stat-value", exact_text: "0")
      end

      it "names the blog post due first" do
        create(:post, :scheduled, title: "Blog", published_at: Time.now + 60)
        schedule_social("Social", at: Time.now + 120)
        get "/admin"

        expect(queue_stat).to have_css(".stat-change", exact_text: "next: Blog")
      end

      it "names the social post due first" do
        create(:post, :scheduled, title: "Blog", published_at: Time.now + 120)
        schedule_social("Social", at: Time.now + 60)
        get "/admin"

        expect(queue_stat).to have_css(".stat-change", exact_text: "next: Social")
      end

      it "reads nothing scheduled with an empty queue" do
        get "/admin"

        expect(queue_stat).to have_css(".stat-change", exact_text: "nothing scheduled")
      end
    end

    describe "Drafts" do
      it "lists only drafts" do
        create(:post, :draft, title: "Draft")
        create(:post, :scheduled, title: "Scheduled")
        create(:post, :published, title: "Published")
        get "/admin"

        expect(titles("Drafts")).to eq(["Draft"])
      end

      it "links each row to its editor" do
        post = create(:post, :draft, title: "Linked")
        get "/admin"

        expect(card("Drafts")).to have_link("Linked", href: "/admin/posts/#{post.id}/edit", class: "li-title")
      end

      it "shows the word count and read time under the title" do
        create(:post, :draft, body: (["word"] * 660).join(" "))
        get "/admin"

        expect(card("Drafts")).to have_css(".li-sub", exact_text: "660 words · ~3 min read")
      end

      it "counts one word in the singular" do
        create(:post, :draft, body: "one")
        get "/admin"

        expect(card("Drafts")).to have_css(".li-sub", exact_text: "1 word · ~1 min read")
      end

      it "reads No drafts. Suspicious. without drafts" do
        create(:post, :scheduled)
        get "/admin"

        expect(card("Drafts")).to have_css(".empty", exact_text: i18n.t("ui.components.drafts_card.empty"))
      end
    end

    describe "Webmentions pending" do
      it "leaves the card out without a pending mention" do
        create(:webmention, :approved)
        create(:webmention, :spam)
        get "/admin"

        expect(page).to have_no_css(".card-title", text: "Webmentions pending")
      end

      it "shows the three newest pending mentions" do
        4.times { |index| create(:webmention, author_name: "A#{index}", received_at: Time.now - index) }
        get "/admin"

        expect(titles("Webmentions pending")).to eq(%w[A0 A1 A2])
      end

      it "leaves out approved and spam mentions" do
        create(:webmention, author_name: "Ada")
        create(:webmention, :approved, author_name: "Grace")
        create(:webmention, :spam, author_name: "Alan")
        get "/admin"

        expect(titles("Webmentions pending")).to eq(%w[Ada])
      end

      it "links the author to the source" do
        create(:webmention, author_name: "Ada", source_url: "https://ada.example/note")
        get "/admin"

        expect(pending_card).to have_link("Ada", href: "https://ada.example/note", class: "li-title")
      end

      it "names the author's domain without a name" do
        create(:webmention, author_name: nil, author_url: "https://ada.example/about")
        get "/admin"

        expect(titles("Webmentions pending")).to eq(%w[ada.example])
      end

      it "names the source without a name or an author page" do
        create(:webmention, author_name: nil, author_url: nil, source_url: "https://ada.example/note")
        get "/admin"

        expect(titles("Webmentions pending")).to eq(%w[https://ada.example/note])
      end

      it "puts the type and the excerpt under the author" do
        create(:webmention, :reply, excerpt: "Good one")
        get "/admin"

        expect(pending_card).to have_css(".li-sub", exact_text: "reply · Good one")
      end

      it "reads only the type for a mention with no excerpt" do
        create(:webmention, :like)
        get "/admin"

        expect(pending_card).to have_css(".li-sub", exact_text: "like")
      end

      it "opens the webmentions page on the pending filter" do
        create(:webmention)
        get "/admin"

        expect(pending_card).to have_link("Review", href: "/admin/webmentions?status=pending")
      end

      it "sits above the post cards in the right column" do
        create(:webmention)
        get "/admin"

        expect(column(1).all("h2.card-title").map(&:text))
          .to eq(["Webmentions pending", "What ships next", "Drafts"])
      end
    end

    describe "the Webmentions stat" do
      it "counts the pending mentions the same as the card and the palette", :aggregate_failures do
        4.times { create(:webmention) }
        get "/admin"

        expect(webmentions_stat).to have_css(".stat-value", exact_text: "4")
        expect(pending_card).to have_css(".wm-count", exact_text: "4 pending")
        expect(page).to have_css("#command-palette-webmentions .pal-r-sub", exact_text: "4 waiting", visible: :all)
      end

      it "names the stat and notes what the count waits for", :aggregate_failures do
        get "/admin"

        expect(webmentions_stat).to have_css(".stat-key", exact_text: "Webmentions")
        expect(webmentions_stat).to have_css(".stat-change", exact_text: "awaiting review")
      end

      it "reads zero without a pending mention" do
        create(:webmention, :approved)
        get "/admin"

        expect(webmentions_stat).to have_css(".stat-value", exact_text: "0")
      end
    end

    describe "the journal card" do
      before { get "/admin" }

      it "labels and titles the card", :aggregate_failures do
        expect(card("Journal")).to have_css(".card-label", exact_text: "Private")
        expect(card("Journal")).to have_css("h2.card-title", exact_text: "Journal")
      end

      it "posts the entry form to Today with the CSRF token", :aggregate_failures do
        expect(page).to have_css("form#today-journal-entry[method='post'][action='/admin']")
        expect(page).to have_css("form#today-journal-entry input[name='_csrf_token']", visible: :hidden)
      end

      it "renders a four row textarea" do
        placeholder = i18n.t("ui.components.today_journal_card.placeholder")

        expect(page).to have_field("Entry", type: "textarea", with: "", placeholder:)
      end

      it "sets the textarea to four rows" do
        expect(page).to have_css("#today-journal-entry textarea[name='entry[body]'][rows='4']")
      end

      it "puts a lock and the word count in the footer", :aggregate_failures do
        expect(card("Journal")).to have_css(".today-journal-foot i.fa-lock")
        expect(card("Journal")).to have_css(".today-journal-foot .journal-words", exact_text: "private · 0 words")
      end

      it "gives the script the word templates" do
        words = page.find("#today-journal-entry [data-journal-words]")

        expect([words["data-one"], words["data-other"]]).to eq(i18n.t("ui.components.today_journal_card.words").values)
      end

      it "disables Save entry while the entry is empty" do
        expect(page).to have_button("Save entry", disabled: true)
      end

      it "lists no entries without any" do
        expect(page).to have_no_css(".today-journal-entries")
      end
    end

    describe "the counts" do
      it "counts today's entries in the card head" do
        2.times { create_entry(entry_date: today) }
        create_entry(entry_date: today - 1)
        get "/admin"

        expect(card("Journal")).to have_css(".card-side .journal-words", exact_text: "2 today")
      end

      it "counts no entries as zero" do
        create_entry(entry_date: today - 1)
        get "/admin"

        expect(card("Journal")).to have_css(".card-side .journal-words", exact_text: "0 today")
      end
    end

    describe "the Journaled stat" do
      before do
        create_entry(entry_date: today, body: "one two three")
        create_entry(entry_date: today, body: "four")
        create_entry(entry_date: today - 1, body: "five six")
        get "/admin"
      end

      it "sums today's words", :aggregate_failures do
        expect(journaled_stat).to have_css(".stat-key", exact_text: "Journaled")
        expect(journaled_stat).to have_css(".stat-value", exact_text: "4")
      end

      it "notes that the words are private" do
        expect(journaled_stat).to have_css(".stat-change", exact_text: "words, private")
      end
    end

    it "reads zero journaled words without entries today" do
      create_entry(entry_date: today - 1, body: "five six")
      get "/admin"

      expect(page).to have_css(".g-4 .stat .stat-value", exact_text: "0")
    end

    describe "today's entries" do
      it "lists them under a rule with their times", :aggregate_failures do
        create_entry(entry_date: today, entry_time: "21:05", body: "walked")
        get "/admin"

        entry = card("Journal").find(".today-journal-entries .today-journal-entry")

        expect(entry).to have_css("time.today-journal-time[datetime='#{today.iso8601}T21:05']", exact_text: "21:05")
        expect(entry).to have_css(".journal-entry-body", exact_text: "walked")
      end

      it "lists today's entries newest first" do
        create_entry(entry_date: today, entry_time: "08:00", body: "earlier")
        create_entry(entry_date: today, entry_time: "21:05", body: "later")
        get "/admin"

        expect(card("Journal").all(".today-journal-entry .journal-entry-body").map(&:text)).to eq(%w[later earlier])
      end

      it "leaves out other days" do
        create_entry(entry_date: today - 1, body: "yesterday")
        get "/admin"

        expect(page).to have_no_css(".today-journal-entries")
      end

      it "keeps the line breaks in a body" do
        create_entry(entry_date: today, body: "first\nsecond")
        get "/admin"

        expect(page.find(".today-journal-entries .journal-entry-body").native.inner_html).to eq("first\nsecond")
      end
    end

    describe "the commits card" do
      before { with_token }

      it "labels and titles the card", :aggregate_failures do
        get "/admin"

        expect(commits_card).to have_css(".card-label", exact_text: "Git")
        expect(commits_card).to have_css("h2.card-title", exact_text: "Commits imported today")
      end

      it "gives a commit its short SHA, message, repo and time", :aggregate_failures do
        create_detailed_commit
        get "/admin"

        expect(commit_row).to have_css(".commit-sha", exact_text: "9f8e7d6")
        expect(commit_row).to have_css(".commit-message", exact_text: "admin: add the commits card")
        expect(commit_row).to have_css(".commit-meta", exact_text: "aaronmallen/blog · 14:05")
      end

      it "gives a commit its additions and deletions", :aggregate_failures do
        create_detailed_commit
        get "/admin"

        expect(commit_row).to have_css(".commit-added", exact_text: "+120")
        expect(commit_row).to have_css(".commit-removed", exact_text: "−8")
      end

      it "lists today's commits newest first" do
        create_commit(commit_date: today, commit_time: "08:00", message: "earlier")
        create_commit(commit_date: today, commit_time: "21:05", message: "later")
        get "/admin"

        expect(commits_card.all(".commit-message").map(&:text)).to eq(%w[later earlier])
      end

      it "gives a commit its subject, leaving the body to its page" do
        create_commit(commit_date: today, message: "admin: add the card\n\nand say why it exists")
        get "/admin"

        expect(commit_row).to have_css(".commit-message", exact_text: "admin: add the card")
      end

      it "leaves out other days" do
        create_commit(commit_date: today - 1, message: "yesterday")
        get "/admin"

        expect(commits_card).to have_no_css(".commits")
      end

      it "shows an empty state without commits today" do
        get "/admin"

        expect(commits_card).to have_css(".empty", exact_text: i18n.t("ui.components.commits_card.empty"))
      end
    end

    describe "the commits sub-line" do
      before { with_token }

      def record_sync(at:)
        commit_repo.record_synced_through("aaronmallen/blog", at: at - Record::CommitEdge::OVERLAP)
        Record::Slice["relations.sync_states"].of_kind("commits").update(updated_at: at)
      end

      it "gives the time the newest walk reached its forward edge, not the edge itself" do
        commit_repo.record_synced_through("aaronmallen/other", at: Time.utc(2026, 1, 9, 15, 30))
        record_sync(at: Time.utc(2026, 1, 7, 15, 30))
        get "/admin"

        expect(commits_card).to have_css(".commits-sub", text: "Last synced Jan 7, 2026, 09:30")
      end

      it "reads Never synced before the first import", :aggregate_failures do
        get "/admin"

        expect(commits_card).to have_css(".commits-sub i.fa-github")
        expect(commits_card).to have_css(".commits-sub", exact_text: "Never synced · 0 repos in 30 days")
      end

      it "gives the Chicago clock time of a sync from today" do
        record_sync(at: Time.now)
        clock = Blog::TimeZone.local(commit_repo.last_synced_at).strftime("%H:%M")
        get "/admin"

        expect(commits_card).to have_css(".commits-sub", text: "Last synced today at #{clock}")
      end

      it "gives the date of a sync from another day" do
        record_sync(at: Time.utc(2026, 1, 7, 15, 30))
        get "/admin"

        expect(commits_card).to have_css(".commits-sub", text: "Last synced Jan 7, 2026, 09:30")
      end

      it "counts the repos pushed to in the last thirty days" do
        create_commit(repo: "aaronmallen/blog", commit_date: today)
        create_commit(repo: "aaronmallen/blog", commit_date: today - 29)
        create_commit(repo: "aaronmallen/other", commit_date: today - 29)
        get "/admin"

        expect(commits_card).to have_css(".commits-sub", text: "2 repos in 30 days")
      end

      it "leaves out repos last pushed to over thirty days ago" do
        create_commit(repo: "aaronmallen/blog", commit_date: today - 30)
        get "/admin"

        expect(commits_card).to have_css(".commits-sub", text: "0 repos in 30 days")
      end

      it "counts one repo in the singular" do
        create_commit(repo: "aaronmallen/blog", commit_date: today)
        get "/admin"

        expect(commits_card).to have_css(".commits-sub", text: "1 repo in 30 days")
      end
    end

    describe "the sync failures" do
      def bad_gateway(path) = Dry::Monads::Failure([:github_failed, "GitHub answered 502 for #{path}"])

      def bad_gateway_line(sync, path)
        /\A#{sync} failed at .+ · GitHub didn't answer · GitHub answered 502 for #{path}\z/
      end

      def country_line(failure)
        with_country_database(failure)

        failure_lines.first.to_s
      end

      def dead_key_line
        /\ACountry database refresh failed at .+ · The download failed · MaxMind answered 401 for GeoLite2-Country\z/
      end

      def dead_maxmind_key = Dry::Monads::Failure([:download_failed, "MaxMind answered 401 for GeoLite2-Country"])

      def fail_twice(reason, repo: nil)
        record_commit_failure(reason, at: first_failed_at, repo:)
        record_commit_failure(reason, repo:)
      end

      def failed_at = Time.utc(2026, 1, 7, 15, 30)

      def failure_lines = page.all(".sync-failures .sync-failure").map(&:text)

      def first_failed_at = Time.utc(2025, 12, 20, 15, 30)

      def import_commits_with(result)
        import = instance_double(Record::Operations::ImportCommits, call: result)
        Record::Jobs::ImportCommits.new(import_commits: import).perform
      end

      def message_line
        "Commit import failed at Jan 7, 2026, 09:30 · GitHub didn't answer · GitHub answered 502"
      end

      def record_commit_failure(reason, at: failed_at, message: nil, repo: nil)
        sync_state_repo.record_failure(Record::Repos::SyncStateRepo::COMMITS, reason, at:, message:, repo:)
      end

      def refresh_country_database_with(result)
        refresh = instance_double(Analytics::Operations::RefreshCountryDatabase, call: result)
        Analytics::Jobs::RefreshCountryDatabase.new(refresh_country_database: refresh).perform
      rescue Analytics::Jobs::RefreshCountryDatabase::RefreshFailed
        nil
      end

      def refresh_projects_with(result)
        refresh = instance_double(Projects::Operations::RefreshProjects, call: result)
        Projects::Jobs::RefreshProjects.new(refresh_projects: refresh).perform
      end

      def repo_streak_line
        "Commit import failed for aaronmallen/one at Jan 7, 2026, 09:30 · GitHub rate limited it · " \
          "failing since Dec 20, 2025"
      end

      def streak_message_line
        "Commit import failed at Jan 7, 2026, 09:30 · GitHub didn't answer · failing since Dec 20, 2025 · " \
          "GitHub answered 502"
      end

      def sync_state_repo = Record::Slice["repos.sync_state_repo"]

      def with_country_database(failure)
        query = instance_double(Analytics::Queries::CountryDatabaseFailure, call: failure)
        replace_component("analytics.queries.country_database_failure", query)
        get "/admin"
      end

      it "says nothing while both syncs are healthy" do
        get "/admin"

        expect(page).to have_no_css(".sync-failures")
      end

      it "names the rate limit that stopped the commit import", :aggregate_failures do
        sync_state_repo.record_failure(Record::Repos::SyncStateRepo::COMMITS, :rate_limited, at: failed_at)
        get "/admin"

        expect(page).to have_css(".sync-failures .sync-failure i.fa-triangle-exclamation")
        expect(failure_lines).to eq(["Commit import failed at Jan 7, 2026, 09:30 · GitHub rate limited it"])
      end

      it "tells another failure from a rate limit" do
        sync_state_repo.record_failure(Record::Repos::SyncStateRepo::COMMITS, :github_failed, at: failed_at)
        get "/admin"

        expect(failure_lines).to eq(["Commit import failed at Jan 7, 2026, 09:30 · GitHub didn't answer"])
      end

      it "names the missing token behind a sync that never ran" do
        sync_state_repo.record_failure(Record::Repos::SyncStateRepo::COMMITS, :not_configured, at: failed_at)
        get "/admin"

        expect(failure_lines).to eq(["Commit import failed at Jan 7, 2026, 09:30 · No GitHub token is set"])
      end

      it "reports the nightly project refresh the same way" do
        sync_state_repo.record_failure(Record::Repos::SyncStateRepo::PROJECTS, :github_failed, at: failed_at)
        get "/admin"

        expect(failure_lines).to eq(["Project refresh failed at Jan 7, 2026, 09:30 · GitHub didn't answer"])
      end

      it "reports the nightly analytics rollup the same way" do
        sync_state_repo.record_failure(Record::Repos::SyncStateRepo::ANALYTICS_ROLLUP, :rollup_failed, at: failed_at)
        get "/admin"

        expect(failure_lines).to eq(["Analytics rollup failed at Jan 7, 2026, 09:30 · The days wouldn't roll up"])
      end

      it "still reports a reason no one has written words for" do
        sync_state_repo.record_failure(Record::Repos::SyncStateRepo::COMMITS, :teapot, at: failed_at)
        get "/admin"

        expect(failure_lines).to eq(["Commit import failed at Jan 7, 2026, 09:30 · teapot"])
      end

      it "names the repository whose import failed" do
        record_commit_failure(:rate_limited, repo: "aaronmallen/one")
        get "/admin"

        expect(failure_lines)
          .to eq(["Commit import failed for aaronmallen/one at Jan 7, 2026, 09:30 · GitHub rate limited it"])
      end

      it "leaves a repository the page limit stopped unreported" do
        record_commit_failure(:page_limit, repo: "aaronmallen/big")
        record_commit_failure(:rate_limited, repo: "aaronmallen/one")
        get "/admin"

        expect(failure_lines)
          .to eq(["Commit import failed for aaronmallen/one at Jan 7, 2026, 09:30 · GitHub rate limited it"])
      end

      it "links nowhere for a repository the page limit stopped", :aggregate_failures do
        record_commit_failure(:page_limit, repo: "aaronmallen/big")
        get "/admin"

        expect(last_response.body).not_to include("aaronmallen/big")
        expect(page).to have_no_css("a[href^='/admin/commits/backfill']")
      end

      it "keeps one repository's failure while another imports cleanly" do
        record_commit_failure(:rate_limited, repo: "aaronmallen/one")
        sync_state_repo.clear_failure(Record::Repos::SyncStateRepo::COMMITS, repo: "aaronmallen/two")
        get "/admin"

        expect(failure_lines.size).to eq(1)
      end

      it "lists both syncs when both failed" do
        sync_state_repo.record_failure(Record::Repos::SyncStateRepo::COMMITS, :rate_limited, at: failed_at)
        sync_state_repo.record_failure(Record::Repos::SyncStateRepo::PROJECTS, :github_failed, at: failed_at)
        get "/admin"

        expect(failure_lines.size).to eq(2)
      end

      it "reads out the message a failure came with, not the reason alone" do
        record_commit_failure(:github_failed, message: "GitHub answered 502")
        get "/admin"

        expect(failure_lines).to eq([message_line])
      end

      it "keeps the message last on a sync that has been failing a while" do
        record_commit_failure(:github_failed, at: first_failed_at, message: "GitHub answered 502")
        record_commit_failure(:github_failed, message: "GitHub answered 502")
        get "/admin"

        expect(failure_lines).to eq([streak_message_line])
      end

      it "reads what GitHub answered off a failed commit import" do
        import_commits_with(bad_gateway("GraphQL"))
        get "/admin"

        expect(failure_lines.first).to match(bad_gateway_line("Commit import", "GraphQL"))
      end

      it "reads what GitHub answered off a failed project refresh" do
        refresh_projects_with(bad_gateway("/repos/aaronmallen/blog"))
        get "/admin"

        expect(failure_lines.first).to match(bad_gateway_line("Project refresh", "/repos/aaronmallen/blog"))
      end

      it "reads a dead MaxMind key off the failed refresh, message and all" do
        refresh_country_database_with(dead_maxmind_key)
        get "/admin"

        expect(failure_lines.first).to match(dead_key_line)
      end

      it "says the database is gone rather than leaving every visitor unknown" do
        expect(country_line(:missing)).to eq("Country lookup · No database on disk")
      end

      it "says the country database will not open" do
        expect(country_line(:unreadable)).to eq("Country lookup · The database won't open")
      end

      it "lists a standing state beside a sync that failed once" do
        sync_state_repo.record_failure(Record::Repos::SyncStateRepo::COMMITS, :rate_limited, at: failed_at)
        with_country_database(:missing)

        expect(failure_lines.last).to eq("Country lookup · No database on disk")
      end

      it "says nothing while the country database reads" do
        with_country_database(nil)

        expect(page).to have_no_css(".sync-failures")
      end

      it "drops the line once the sync succeeds" do
        sync_state_repo.record_failure(Record::Repos::SyncStateRepo::COMMITS, :rate_limited, at: failed_at)
        sync_state_repo.clear_failure(Record::Repos::SyncStateRepo::COMMITS)
        get "/admin"

        expect(page).to have_no_css(".sync-failures")
      end

      it "says how long a sync has been failing once it fails twice" do
        fail_twice(:github_failed)
        get "/admin"

        expect(failure_lines)
          .to eq(["Commit import failed at Jan 7, 2026, 09:30 · GitHub didn't answer · failing since Dec 20, 2025"])
      end

      it "says how long a repository has been failing to import" do
        fail_twice(:rate_limited, repo: "aaronmallen/one")
        get "/admin"

        expect(failure_lines).to eq([repo_streak_line])
      end

      it "says nothing about how long after one failure" do
        record_commit_failure(:github_failed)
        get "/admin"

        expect(failure_lines).to eq(["Commit import failed at Jan 7, 2026, 09:30 · GitHub didn't answer"])
      end

      it "drops the streak once the sync recovers and fails again" do
        fail_twice(:github_failed)
        sync_state_repo.clear_failure(Record::Repos::SyncStateRepo::COMMITS)
        record_commit_failure(:github_failed)
        get "/admin"

        expect(failure_lines).to eq(["Commit import failed at Jan 7, 2026, 09:30 · GitHub didn't answer"])
      end
    end

    describe "Import now" do
      before do
        with_token
        get "/admin"
      end

      it "posts to the import route with the CSRF token", :aggregate_failures do
        expect(commits_card).to have_css("form[data-commits-import][method='post'][action='/admin/commits/import']")
        expect(commits_card).to have_css("form[data-commits-import] input[name='_csrf_token']", visible: :hidden)
      end

      it "reads Import now with a rotate icon", :aggregate_failures do
        expect(commits_card).to have_css("[data-commits-idle]", exact_text: "Import now")
        expect(commits_card).to have_css("[data-commits-idle] i.fa-rotate")
      end

      it "hides the Importing… label until the import starts", :aggregate_failures do
        busy = commits_card.find("[data-commits-busy]", visible: :hidden)

        expect(busy).to have_text("Importing…", exact: true)
        expect(busy).not_to be_visible
      end

      it "spins only the Importing… icon", :aggregate_failures do
        expect(commits_card).to have_css("[data-commits-busy] i.commit-spinner", visible: :all)
        expect(commits_card).to have_no_css("[data-commits-idle] i.commit-spinner")
      end

      it "enables the button while the token is set" do
        expect(commits_card).to have_button("Import now", disabled: false)
      end

      it "shows no token hint while the token is set" do
        expect(commits_card).to have_no_css(".hint")
      end
    end

    describe "Import now without a token" do
      before do
        disconnect_github
        get "/admin"
      end

      it "disables the button" do
        expect(commits_card).to have_button("Import now", disabled: true)
      end

      it "says the token isn't set" do
        expect(commits_card).to have_css(".hint", exact_text: i18n.t("ui.components.commits_card.no_token"))
      end
    end

    describe "the Commits stat" do
      before do
        create_commit(commit_date: today, additions: 120, deletions: 8)
        create_commit(commit_date: today, additions: 5, deletions: 2)
        create_commit(commit_date: today - 1, additions: 99, deletions: 99)
        get "/admin"
      end

      it "counts today's commits", :aggregate_failures do
        expect(commits_stat).to have_css(".stat-key", exact_text: "Commits")
        expect(commits_stat).to have_css(".stat-value", exact_text: "2")
      end

      it "sums today's additions and deletions" do
        expect(commits_stat).to have_css(".stat-change", exact_text: "+125 / −10")
      end

      it "matches the rows on the card" do
        expect(commits_stat.find(".stat-value").text).to eq(commits_card.all(".commit").size.to_s)
      end
    end

    it "reads zero commits with none today", :aggregate_failures do
      create_commit(commit_date: today - 1)
      get "/admin"

      expect(commits_stat).to have_css(".stat-value", exact_text: "0")
      expect(commits_stat).to have_css(".stat-change", exact_text: "+0 / −0")
    end

    describe "saving an entry" do
      it "files it under today with the time of saving", :aggregate_failures do
        before_save = Blog::TimeZone.local(Time.now - 1)
        save(body: "walked")
        entry = repo.today.first

        expect(entry).to have_attributes(body: "walked", entry_date: today)
        expect(entry.entry_time.strftime("%H:%M:%S")).to be >= before_save.strftime("%H:%M:%S")
      end

      it "returns to Today with the toast", :aggregate_failures do
        save(body: "walked")
        follow_redirect!

        expect(last_request.path).to eq("/admin")
        expect(toast).to eq("Journal entry saved · private")
      end

      it "lists the new entry under the card" do
        save(body: "walked")
        follow_redirect!

        expect(card("Journal").all(".today-journal-entry .journal-entry-body").map(&:text)).to eq(["walked"])
      end

      it "files it under today even when a date comes with the form" do
        save(body: "walked", entry_date: (today - 4).iso8601)

        expect(repo.today.map(&:body)).to eq(["walked"])
      end

      it "clears the textarea" do
        save(body: "walked")
        follow_redirect!

        expect(page).to have_field("Entry", with: "")
      end
    end

    describe "a rejected entry" do
      it "answers 422 and saves nothing for a blank entry" do
        save(body: " \n ")

        expect([last_response.status, repo.count]).to eq([422, 0])
      end

      it "shows the body error next to the textarea", :aggregate_failures do
        save(body: "  ")
        message = i18n.t("ui.components.journal.field_error.body.blank")

        expect(page).to have_css("#journal-body-error.field-error", exact_text: message)
        expect(page).to have_css("#journal-body[aria-invalid='true'][aria-describedby='journal-body-error']")
      end

      it "stays on Today with the post cards", :aggregate_failures do
        create(:post, :draft, title: "Draft")
        save(body: "  ")

        expect(column(0).all("h2.card-title").map(&:text))
          .to eq(["Journal", "Commits imported today"])
        expect(titles("Drafts")).to eq(["Draft"])
      end

      it "rejects a save without a CSRF token" do
        post "/admin", entry: { body: "walked" }

        expect([last_response.status, repo.count]).to eq([403, 0])
      end
    end

    describe "the sprint" do
      def lose_the_roll
        failing = sprint_repo
        allow(failing).to receive(:by_id).and_return(nil)
        replace_component("repos.sprint_repo", failing)
      end

      def panel = page.find(".sprint-panel")

      def plan(*titles, done: 0)
        titles.each_with_index do |title, index|
          create(:task, :in_sprint, *([:done] if index < done), sprint_id: sprint.id, title:)
        end
      end

      def planner(key, **) = i18n.t(["ui.components.tasks.planner", key].join("."), **)

      def quick_add(title)
        fields = { _csrf_token: admin_csrf_token, filter: "today", origin: "today", task: { title: } }

        post "/admin/tasks", fields
      end

      def sprint = @sprint ||= create(:sprint, sprint_date: today)

      def sprint_repo = Tasks::Slice["repos.sprint_repo"]

      def sprint_stat = page.find(".g-4 .stat", text: "Sprint")

      def task_repo = Tasks::Slice["repos.task_repo"]

      it "reads the day as the page title" do
        get "/admin"

        expect(page).to have_css(".page-head-title", text: today.strftime("%A, %B %-d"))
      end

      it "opens the sub-line with the sprint" do
        plan("Ship the panel", "Read the design", done: 1)
        get "/admin"

        expect(page).to have_css(".page-head-sub", text: "1/2 tasks done")
      end

      it "counts the commits, entries and what is due today in the sub-line" do
        get "/admin"

        expect(page).to have_css(".page-head-sub", text: "0 commits · 0 journal entries · 0 scheduled today")
      end

      it "puts the sprint stat first in the row" do
        get "/admin"

        expect(page.all(".g-4 .stat .stat-key").map(&:text).first).to eq("Sprint")
      end

      it "reads the stat as done over total" do
        plan("Ship the panel", "Read the design", done: 1)
        get "/admin"

        expect(sprint_stat).to have_css(".stat-value", text: "1/2")
      end

      it "counts what is still open under the stat" do
        plan("Ship the panel", "Read the design", done: 1)
        get "/admin"

        expect(sprint_stat).to have_css(".stat-change", text: "1 still open")
      end

      it "says nothing is planned for an empty sprint" do
        get "/admin"

        expect(sprint_stat).to have_css(".stat-change.down", text: "nothing planned")
      end

      it "puts the panel between the stats and the two columns" do
        get "/admin"

        expect(page).to have_css(".g-4 + .sprint-panel + .g-2")
      end

      it "labels the panel with the day's sprint" do
        plan("Ship the panel")
        get "/admin"

        expect(panel).to have_css(".card-label", text: "Sprint · #{Blog::TimeZone.today.strftime('%b %-d')}")
      end

      it "lists the open tasks" do
        plan("Ship the panel", "Read the design", done: 1)
        get "/admin"

        expect(panel.all(".task-title").map(&:text)).to eq(["Read the design"])
      end

      it "leads each open task with its key" do
        tasks = %w[Ship Read].map { create(:task, :in_sprint, sprint_id: sprint.id, title: it) }
        get "/admin"

        expect(panel.all(".task-key").map(&:text)).to match_array(tasks.map { "##{it.id}" })
      end

      it "fills the progress bar with the share that is done" do
        plan("Ship the panel", "Read the design", done: 1)
        get "/admin"

        expect(panel.find(".sprint-progress-fill", visible: :all)[:style]).to eq("width: 50%")
      end

      it "notes the count done beside the title" do
        plan("Ship the panel", "Read the design", done: 1)
        get "/admin"

        expect(panel).to have_css(".sprint-note", text: "1/2 done")
      end

      it "says the sprint is clear when everything is done" do
        plan("Ship the panel", done: 1)
        get "/admin"

        expect(panel).to have_css(".card-title", text: "Sprint clear")
      end

      it "counts what was finished when everything is done" do
        plan("Ship the panel", done: 1)
        get "/admin"

        expect(panel).to have_css(".empty", text: "1 finished")
      end

      it "still offers the quick add when everything is done" do
        plan("Ship the panel", done: 1)
        get "/admin"

        expect(panel).to have_css(".sprint-foot .task-capture input[name='task[title]']")
      end

      it "offers the planner when the sprint holds nothing" do
        get "/admin"

        expect(panel).to have_css(".task-planner .card-title", text: planner("ask"))
      end

      it "heads the planner with the sprint date" do
        label = planner("label", date: today.strftime("%b %-d, %Y"))
        get "/admin"

        expect(panel).to have_css(".task-planner .card-label", exact_text: label)
      end

      it "offers a quick add with the planner" do
        get "/admin"

        expect(panel).to have_css(".task-capture input[name='task[title]']")
      end

      it "counts both pools the planner can pull from" do
        create(:task, title: "Email the accountant")
        create(:task, :someday, title: "Learn Elixir")
        get "/admin"

        expect(panel.all(".seg-option").map(&:text)).to eq(["next · 1", "someday · 1"])
      end

      it "keeps Today when switching the pool" do
        get "/admin"

        expect(panel.all(".seg-option").map { it["href"] }).to eq(["/admin?pool=next", "/admin?pool=someday"])
      end

      it "pulls from someday when that pool is asked for" do
        create(:task, title: "Email the accountant")
        create(:task, :someday, title: "Learn Elixir")
        get "/admin", pool: "someday"

        expect(panel.all(".li-title").map(&:text)).to eq(["Learn Elixir"])
      end

      it "says which pool is empty" do
        get "/admin"

        expect(panel).to have_css(".empty", exact_text: planner("empty_next"))
      end

      it "comes back to Today after pulling a task in" do
        task = create(:task)
        post "/admin/tasks/#{task.id}/move/today", _csrf_token: admin_csrf_token, origin: "today"

        expect(last_response.headers["location"]).to eq("/admin")
      end

      it "links through to the tasks screen" do
        plan("Ship the panel")
        get "/admin"

        expect(panel).to have_css(".sprint-foot a[href='/admin/tasks']", text: "All tasks")
      end

      it "offers to pull from next when the sprint is clear" do
        plan("Ship the panel", done: 1)
        get "/admin"

        expect(panel).to have_css(".sprint-foot a[href='/admin/tasks']", text: "Pull from next")
      end

      it "claims today's sprint as it loads" do
        get "/admin"

        expect(sprint_repo.on(Blog::TimeZone.today).sprint_date).to eq(today)
      end

      it "carries yesterday's open work into today as it loads" do
        yesterday = create(:sprint, sprint_date: today - 1)
        task = create(:task, :in_sprint, sprint_id: yesterday.id)
        get "/admin"

        expect(task_repo.by_id(task.id).sprint_id).to eq(sprint_repo.on(Blog::TimeZone.today).id)
      end

      it "draws the work it carried forward" do
        yesterday = create(:sprint, sprint_date: today - 1)
        create(:task, :in_sprint, sprint_id: yesterday.id, title: "Read the design")
        get "/admin"

        expect(panel.all(".task-title").map(&:text)).to eq(["Read the design"])
      end

      it "answers with a server error when the day's sprint cannot be rolled" do
        create(:task, :in_sprint, sprint_id: create(:sprint, sprint_date: today - 1).id)
        lose_the_roll
        get "/admin"

        expect(last_response.status).to eq(500)
      end

      it "writes a task from the quick add straight into today" do
        quick_add("Ship the panel")

        expect(task_repo.in_sprint(sprint_repo.on(Blog::TimeZone.today).id).map(&:title)).to eq(["Ship the panel"])
      end

      it "comes back to Today after the quick add" do
        quick_add("Ship the panel")

        expect(last_response.headers["location"]).to eq("/admin")
      end

      it "comes back to Today after finishing a task from the panel" do
        plan("Ship the panel")
        task = task_repo.in_sprint(sprint.id).first
        post "/admin/tasks/#{task.id}/complete", _csrf_token: admin_csrf_token, filter: "today", origin: "today"

        expect(last_response.headers["location"]).to eq("/admin")
      end

      it "says what is missing when the quick add carries no title" do
        quick_add("")
        follow_redirect!

        expect(page).to have_css("[data-toast] .toast", text: "Write the task down first", visible: :all)
      end
    end
  end

  describe "signed out" do
    it "saves nothing" do
      post "/admin", entry: { body: "walked" }

      expect(repo.count).to eq(0)
    end
  end
end
