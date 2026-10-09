# frozen_string_literal: true

RSpec.describe "Admin today", :frozen_clock, type: :request do
  let(:page) { Capybara.string(last_response.body) }
  let(:i18n) { Admin::Slice["i18n"] }
  let(:today) { Blog::TimeZone.today }
  let(:toast) { page.find("[data-toast] .toast", visible: :all).text(:all) }

  def card(title) = page.all("section.card").find { it.has_css?("h2.card-title", exact_text: title) }

  def column(name) = page.all(".today-#{name} > section.card h2.card-title").map(&:text)

  def commit_mutations = Record::Slice["repos.commit_mutations"]
  def commit_queries = Record::Slice["repos.commit_queries"]

  def commit_row = commits_card.find(".commits .commit")

  def commits_card = card("Shipped today")

  def commits_stat = commits_card.find(".today-stat")

  def create_commit(**attributes) = create(:commit, **attributes)

  def create_detailed_commit
    create_commit(
      sha: "9f8e7d6c5b4a39281706f5e4d3c2b1a098765432", repo: "aaronmallen/blog", commit_date: today,
      commit_time: "14:05", message: "admin: add the commits card", additions: 120, deletions: 8,
    )
  end

  def create_entry(**attributes) = create(:journal_entry, **attributes)

  def line(label) = page.find(".today-line", text: label)

  def line_value(label) = line(label).find(".today-line-value").text

  def mcp_create(name, *traits, **) = Spec::DB::Factories[:mcp].create(name, *traits, **)

  def schedule_social(*parts, at: Time.now + 60, targets: %w[mastodon])
    Social::Slice["repos.social_post_mutations"].create_with_parts(targets:, status: "scheduled", posted_at: at, parts:)
  end

  def show_hidden
    Capybara.ignore_hidden_elements = false
    yield
  ensure
    Capybara.ignore_hidden_elements = true
  end

  def visit_site(visitor, at: Time.now)
    create(:analytics_event, visitor_hash: Digest::SHA256.hexdigest(visitor), occurred_at: at)
  end

  def with_token
    connect_github_token
  end

  describe "signed in" do
    before { sign_in_to_admin }

    it "puts the sprint on the left and Shipped today on the right", :aggregate_failures do
      get "/admin"

      expect(column("main")).to eq(["Today's sprint"])
      expect(column("side")).to eq(["Shipped today"])
    end

    it "lists the quiet lines under Shipped today" do
      get "/admin"

      expect(page.all(".today-side > .today-quiet .today-line > span:first-child").map(&:text))
        .to eq(["Journal", "What ships next", "Drafts", "Visitors", "MCP clients"])
    end

    it "shows no stat strip" do
      get "/admin"

      expect(page).to have_no_css(".stat")
    end

    describe "What ships next" do
      it "links the soonest scheduled post to its editor" do
        create(:post, :scheduled, published_at: Time.now + 120)
        post = create(:post, :scheduled, published_at: Time.now + 60)
        get "/admin"

        expect(line("What ships next")[:href]).to eq("/admin/posts/#{post.id}/edit")
      end

      it "opens the queue on the queued filter when a social post goes first" do
        create(:post, :scheduled, published_at: Time.now + 600)
        schedule_social("Social")
        get "/admin"

        expect(line("What ships next")[:href]).to eq("/admin/social?filter=queued")
      end

      it "puts the Chicago time of the next item in a time tag", :aggregate_failures do
        create(:post, :scheduled, published_at: Time.utc(2030, 1, 7, 15, 30))
        get "/admin"

        expect(line("What ships next").find("time")[:datetime]).to eq("2030-01-07T09:30:00-06:00")
        expect(line_value("What ships next")).to eq("Jan 7, 2030, 09:30 · 1 queued")
      end

      it "counts scheduled blog posts and scheduled social posts together" do
        2.times { |index| create(:post, :scheduled, published_at: Time.now + (60 * (index + 1))) }
        schedule_social("Social")
        get "/admin"

        expect(line_value("What ships next")).to end_with("· 3 queued")
      end

      it "reads nothing scheduled without a queue" do
        create(:post, :draft)
        create(:post, :published)
        create(:social_post, :posted)
        get "/admin"

        expect(line_value("What ships next")).to eq("nothing scheduled")
      end

      it "opens the calendar without a queue" do
        get "/admin"

        expect(line("What ships next")[:href]).to eq("/admin/calendar")
      end
    end

    describe "Drafts" do
      it "counts only drafts" do
        create(:post, :draft)
        create(:post, :scheduled)
        create(:post, :published)
        get "/admin"

        expect(line_value("Drafts")).to eq("1")
      end

      it "opens the drafts list" do
        get "/admin"

        expect(line("Drafts")[:href]).to eq("/admin/posts?status=draft")
      end

      it "reads none without drafts" do
        create(:post, :scheduled)
        get "/admin"

        expect(line_value("Drafts")).to eq("none")
      end
    end

    describe "Visitors" do
      it "counts each visitor once" do
        2.times { visit_site("first") }
        visit_site("second")
        get "/admin"

        expect(line_value("Visitors")).to eq("2 visitors today")
      end

      it "leaves out visits from before today" do
        visit_site("today")
        visit_site("yesterday", at: Blog::TimeZone.day_start(today) - 1)
        get "/admin"

        expect(line_value("Visitors")).to eq("1 visitor today")
      end

      it "opens analytics" do
        get "/admin"

        expect(line("Visitors")[:href]).to eq("/admin/analytics")
      end
    end

    describe "MCP clients" do
      it "counts the connected clients and opens them", :aggregate_failures do
        mcp_create(:oauth_client).tap { mcp_create(:oauth_token, oauth_client: it) }
        mcp_create(:oauth_client)
        get "/admin"

        expect(line_value("MCP clients")).to eq("1 connected")
        expect(line("MCP clients")[:href]).to eq("/admin/clients")
      end
    end

    describe "pending webmentions" do
      def attention = page.find("section.card[data-attention]")

      it "leaves Needs attention out without a pending mention" do
        create(:webmention, :approved)
        create(:webmention, :spam)
        get "/admin"

        expect(page).to have_no_css("section.card[data-attention]")
      end

      it "counts them in Needs attention the same as the palette's Inbox", :aggregate_failures do
        4.times { create(:webmention) }
        create(:webmention, :approved)
        get "/admin"

        expect(attention.find(".today-line", text: "Webmentions")).to have_text("4 waiting →")
        expect(page).to have_css("#command-palette-inbox .pal-r-sub", exact_text: "4 waiting", visible: :all)
      end

      it "opens the webmentions page on the pending filter" do
        create(:webmention)
        get "/admin"

        expect(attention).to have_link(href: "/admin/webmentions?status=pending")
      end
    end

    describe "the Journal line" do
      it "has no journal card" do
        get "/admin"

        expect(page).to have_no_css("section.card h2.card-title", exact_text: "Journal")
      end

      it "counts today's entries and leaves out other days" do
        2.times { create_entry(entry_date: today) }
        create_entry(entry_date: today - 1)
        get "/admin"

        expect(line_value("Journal")).to eq("2 today w")
      end

      it "opens the journal modal, and the journal page without scripts", :aggregate_failures do
        get "/admin"

        expect(line("Journal")["data-dialog-open"]).to eq("journal-write")
        expect(line("Journal")[:href]).to eq("/admin/journal?write=1")
      end

      it "shows the w key" do
        get "/admin"

        expect(line("Journal")).to have_css("kbd.kbd", exact_text: "w")
      end

      it "reads nothing yet on the quiet Journal line without an entry" do
        get "/admin"

        expect(line_value("Journal")).to eq("nothing yet w")
      end
    end

    describe "the commits card" do
      around { |example| show_hidden(&example) }

      before { with_token }

      it "titles the card Shipped today" do
        get "/admin"

        expect(commits_card).to have_css("h2.card-title", exact_text: "Shipped today")
      end

      it "names the repos and the latest commit under the count" do
        create_commit(repo: "aaronmallen/other", commit_date: today, commit_time: "08:00", message: "earlier")
        create_detailed_commit
        get "/admin"

        expect(commits_card.find(".today-para").text)
          .to eq(i18n.t("ui.components.commits_card.latest", count: 2, subject: "admin: add the commits card"))
      end

      it "counts one repo in the singular" do
        create_commit(repo: "aaronmallen/blog", commit_date: today, message: "one")
        create_commit(repo: "aaronmallen/blog", commit_date: today, message: "two")
        create_commit(repo: "aaronmallen/other", commit_date: today - 1)
        get "/admin"

        expect(commits_card.find(".today-para")).to have_text(/\AAcross 1 repo\. /)
      end

      it "folds the commit list away" do
        create_detailed_commit
        get "/admin"

        expect(commits_card).to have_css("details.today-more:not([open]) .commits")
      end

      it "links each whole commit row to the commit's page", :aggregate_failures do
        commit = create_detailed_commit
        get "/admin"

        expect(commit_row.tag_name).to eq("a")
        expect(commit_row[:href]).to eq("/admin/commits/#{commit.id}")
      end

      it "gives a commit its message, then its short SHA, repo without its owner and time", :aggregate_failures do
        create_detailed_commit
        get "/admin"

        expect(commit_row).to have_css(".commit-message", exact_text: "admin: add the commits card")
        expect(commit_row).to have_css(".commit-meta", exact_text: "9f8e7d6 · blog · 14:05")
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

        expect(commits_card).to have_no_css(".commits", visible: :all)
      end

      it "shows an empty state without commits today" do
        get "/admin"

        expect(commits_card).to have_css(".empty", exact_text: i18n.t("ui.components.commits_card.empty"))
      end

      it "leaves out the activity link without commits today" do
        get "/admin"

        expect(commits_card).to have_no_link(i18n.t("ui.components.commits_card.activity"), visible: :all)
      end
    end

    describe "the commits card on a busy day" do
      around { |example| show_hidden(&example) }

      before do
        12.times do |hour|
          create_commit(commit_date: today, commit_time: format("%02d:00", hour + 8), message: "at #{hour + 8}")
        end
        get "/admin"
      end

      it "lists only the 10 latest commits" do
        expect(commits_card.all(".commit-message").map(&:text)).to eq((10..19).to_a.reverse.map { "at #{it}" })
      end

      it "links under the list to today's commits in activity", :aggregate_failures do
        link = commits_card.find(".commits + .commits-foot a")

        expect(link.text).to eq(i18n.t("ui.components.commits_card.activity"))
        expect(link[:href]).to eq("/admin/activity?from=#{today}&to=#{today}&types%5Bcommit%5D=1")
      end

      it "opens the activity page with every commit from today", :aggregate_failures do
        get commits_card.find(".commits-foot a")[:href]

        expect(last_response).to be_ok
        expect(last_response.body).to include("at 8", "at 19")
      end

      it "still counts every commit from today" do
        expect(commits_stat).to have_text("12 commits")
      end
    end

    describe "the commit list's sync time" do
      around { |example| show_hidden(&example) }

      before do
        with_token
        create_detailed_commit
      end

      def record_sync(at:)
        commit_mutations.record_synced_through("aaronmallen/blog", at: at - Record::Operations::PlanCommitWalk::OVERLAP)
        Record::Slice["relations.sync_states"].of_kind("commits").update(updated_at: at)
      end

      def synced = commits_card.find(".today-more > summary .commits-synced")

      it "gives the time the newest walk reached its forward edge, not the edge itself" do
        commit_mutations.record_synced_through("aaronmallen/other", at: Time.utc(2026, 1, 9, 15, 30))
        record_sync(at: Time.utc(2026, 1, 7, 15, 30))
        get "/admin"

        expect(synced).to have_text("synced Jan 7, 2026, 09:30", exact: true)
      end

      it "reads never synced before the first import" do
        get "/admin"

        expect(synced).to have_text("never synced", exact: true)
      end

      it "gives the Chicago clock time of a sync from today" do
        record_sync(at: Time.now)
        clock = Blog::TimeZone.local(commit_queries.last_synced_at).strftime("%H:%M")
        get "/admin"

        expect(synced).to have_text("synced today at #{clock}", exact: true)
      end

      it "puts the sync time in a time tag" do
        record_sync(at: Time.utc(2026, 1, 7, 15, 30))
        get "/admin"

        expect(synced.find("time")[:datetime]).to eq("2026-01-07T09:30:00-06:00")
      end

      it "keeps no standing sync line outside the list" do
        get "/admin"

        expect(commits_card).to have_no_css(".commits-sub")
      end
    end

    describe "the sync failures" do
      def bad_gateway = { status: 502 }

      def bad_gateway_line(sync, path)
        /\A#{sync} failed at .+ · GitHub didn't answer · GitHub answered 502 for #{path}\z/
      end

      def connect_country_database
        use_country_database
        connect_maxmind_client
      end

      def fail_both_issue_syncs
        sync_issues_answered(bad_gateway)
        sync_linear_issues_answered(bad_gateway)
      end

      def fail_twice(reason, repo: nil)
        record_commit_failure(reason, at: first_failed_at, repo:)
        record_commit_failure(reason, repo:)
      end

      def failed_at = Time.utc(2026, 1, 7, 15, 30)

      def failed_syncs = failure_lines.map { it.split(" failed at ").first }

      def failure_lines = page.all(".sync-failures .sync-failure").map(&:text)

      def first_failed_at = Time.utc(2025, 12, 20, 15, 30)

      def import_commits_answered(response)
        connect_github_token
        stub_github(GitHubGraphQL::REPOS_QUERY, response)
        Record::Jobs::ImportCommits.new.perform
      end

      def record_commit_failure(reason, at: failed_at, message: nil, repo: nil)
        sync_state_mutations.record_failure(Blog::Types::SyncName["commits"], reason, at:, message:, repo:)
      end

      def refresh_country_database_answered(response)
        connect_country_database
        stub_maxmind_download(**response)
        Analytics::Jobs::RefreshCountryDatabase.new.perform
      rescue Analytics::Jobs::RefreshCountryDatabase::RefreshFailed
        nil
      end

      def refresh_projects_answered(response)
        connect_github_token
        create(:project, repo: "aaronmallen/blog")
        stub_request(:get, "https://api.github.com/repos/aaronmallen/blog").to_return(response)
        Projects::Jobs::RefreshProjects.new.perform
      end

      def repo_streak_line
        "Commit import failed for aaronmallen/one at Jan 7, 2026, 09:30 · It hit the rate limit · " \
          "failing since Dec 20, 2025"
      end

      def streak_message_line
        "Commit import failed at Jan 7, 2026, 09:30 · GitHub didn't answer · failing since Dec 20, 2025 · " \
          "GitHub answered 502"
      end

      def sync_issues_answered(response)
        connect_github_token
        stub_github(GitHubGraphQL::ASSIGNED_QUERY, response)
        Tasks::Jobs::SyncIssues.new.perform
      end

      def sync_linear_issues_answered(response)
        connect_linear(LinearGraphQL::KEY)
        stub_linear(LinearGraphQL::ASSIGNED_QUERY, response)
        Tasks::Jobs::SyncLinearIssues.new.perform
      end

      def sync_state_mutations = Record::Slice["repos.sync_state_mutations"]

      it "says nothing while both syncs are healthy" do
        get "/admin"

        expect(page).to have_no_css(".sync-failures")
      end

      it "marks a failure with a warning sign" do
        record_commit_failure(:rate_limited)
        get "/admin"

        expect(page).to have_css(".sync-failures .sync-failure i.fa-triangle-exclamation")
      end

      it "reads what GitHub answered off a failed commit import" do
        import_commits_answered(bad_gateway)
        get "/admin"

        expect(failure_lines).to match([bad_gateway_line("Commit import", "GraphQL")])
      end

      it "reads what GitHub answered off a failed project refresh" do
        refresh_projects_answered(bad_gateway)
        get "/admin"

        expect(failure_lines).to match([bad_gateway_line("Project refresh", "/repos/aaronmallen/blog")])
      end

      it "reads what GitHub answered off a failed issue sync" do
        sync_issues_answered(bad_gateway)
        get "/admin"

        expect(failure_lines).to match([bad_gateway_line("GitHub issue sync", "GraphQL")])
      end

      it "reads what Linear answered off a failed Linear issue sync" do
        sync_linear_issues_answered(bad_gateway)
        get "/admin"

        expect(failure_lines)
          .to match([/\ALinear issue sync failed at .+ · Linear didn't answer · Linear answered 502 for GraphQL\z/])
      end

      it "reports the nightly analytics rollup" do
        sync_state_mutations.record_failure(Blog::Types::SyncName["analytics_rollup"], :rollup_failed, at: failed_at)
        get "/admin"

        expect(failure_lines).to eq(["Analytics rollup failed at Jan 7, 2026, 09:30 · The days wouldn't roll up"])
      end

      it "reports a failed database backup" do
        sync_state_mutations.record_failure(Blog::Types::SyncName["backups"], :upload_failed, at: failed_at)
        get "/admin"

        expect(failure_lines).to eq(["Database backup failed at Jan 7, 2026, 09:30 · The dump wouldn't upload"])
      end

      it "puts the failure time in a time tag" do
        sync_state_mutations.record_failure(Blog::Types::SyncName["backups"], :upload_failed, at: failed_at)
        get "/admin"

        expect(page.find(".sync-failure time")[:datetime]).to eq("2026-01-07T09:30:00-06:00")
      end

      it "reads a dead MaxMind key off the failed refresh, message and all" do
        refresh_country_database_answered(status: 401, body: "")
        get "/admin"

        expect(failure_lines.first).to match(
          /\ACountry database refresh failed at .+ · The download failed · MaxMind answered 401 for GeoLite2-City\z/,
        )
      end

      it "says the database is gone rather than leaving every visitor unknown" do
        connect_country_database
        get "/admin"

        expect(failure_lines).to eq(["Country lookup · No database on disk"])
      end

      it "still reports a reason no one has written words for" do
        record_commit_failure(:teapot)
        get "/admin"

        expect(failure_lines).to eq(["Commit import failed at Jan 7, 2026, 09:30 · teapot"])
      end

      it "reports a failed Linear issue sync apart from a failed GitHub one" do
        fail_both_issue_syncs
        get "/admin"

        expect(failed_syncs).to eq(["GitHub issue sync", "Linear issue sync"])
      end

      it "clears a Linear issue sync failure without clearing GitHub's" do
        fail_both_issue_syncs
        sync_linear_issues_answered(linear_assigned)
        get "/admin"

        expect(failure_lines).to match([bad_gateway_line("GitHub issue sync", "GraphQL")])
      end

      it "names the repository whose import failed" do
        record_commit_failure(:rate_limited, repo: "aaronmallen/one")
        get "/admin"

        expect(failure_lines)
          .to eq(["Commit import failed for aaronmallen/one at Jan 7, 2026, 09:30 · It hit the rate limit"])
      end

      it "leaves a repository the page limit stopped unreported" do
        record_commit_failure(:page_limit, repo: "aaronmallen/big")
        record_commit_failure(:rate_limited, repo: "aaronmallen/one")
        get "/admin"

        expect(failure_lines)
          .to eq(["Commit import failed for aaronmallen/one at Jan 7, 2026, 09:30 · It hit the rate limit"])
      end

      it "links nowhere for a repository the page limit stopped", :aggregate_failures do
        record_commit_failure(:page_limit, repo: "aaronmallen/big")
        get "/admin"

        expect(last_response.body).not_to include("aaronmallen/big")
        expect(page).to have_no_css("a[href^='/admin/commits/backfill']")
      end

      it "keeps one repository's failure while another imports cleanly" do
        record_commit_failure(:rate_limited, repo: "aaronmallen/one")
        sync_state_mutations.clear_failure(Blog::Types::SyncName["commits"], repo: "aaronmallen/two")
        get "/admin"

        expect(failure_lines.size).to eq(1)
      end

      it "lists both syncs when both failed" do
        record_commit_failure(:rate_limited)
        sync_state_mutations.record_failure(Blog::Types::SyncName["projects"], :github_failed, at: failed_at)
        get "/admin"

        expect(failure_lines.size).to eq(2)
      end

      it "keeps the message last on a sync that has been failing a while" do
        record_commit_failure(:github_failed, at: first_failed_at, message: "GitHub answered 502")
        record_commit_failure(:github_failed, message: "GitHub answered 502")
        get "/admin"

        expect(failure_lines).to eq([streak_message_line])
      end

      it "lists a standing state beside a sync that failed once" do
        record_commit_failure(:rate_limited)
        connect_country_database
        get "/admin"

        expect(failure_lines.last).to eq("Country lookup · No database on disk")
      end

      it "says nothing while the country database reads" do
        connect_country_database
        write_country_database
        get "/admin"

        expect(page).to have_no_css(".sync-failures")
      end

      it "drops the line once the sync succeeds" do
        record_commit_failure(:rate_limited)
        sync_state_mutations.clear_failure(Blog::Types::SyncName["commits"])
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
        sync_state_mutations.clear_failure(Blog::Types::SyncName["commits"])
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

      it "puts the import button in the card head" do
        expect(commits_card).to have_css(".card-head form[data-commits-import] button[title='Import now']")
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

    describe "the commit count" do
      before do
        create_commit(commit_date: today, additions: 120, deletions: 8)
        create_commit(commit_date: today, additions: 5, deletions: 2)
        create_commit(commit_date: today - 1, additions: 99, deletions: 99)
        get "/admin"
      end

      it "counts today's commits with their additions and deletions" do
        expect(commits_stat).to have_text("2 commits+125 −10", exact: true)
      end

      it "matches the rows on the card" do
        expect(commits_stat.text).to start_with("#{commits_card.all('.commit', visible: :all).size} commits")
      end
    end

    it "shows no commit count with none today" do
      create_commit(commit_date: today - 1)
      get "/admin"

      expect(commits_card).to have_no_css(".today-stat")
    end

    describe "the sprint" do
      def create_from_today(title)
        post "/admin/tasks", _csrf_token: admin_csrf_token, origin: "today", task: { title:, list: "today" }
      end

      def dialog = page.find("dialog#task-create", visible: :all)

      def lose_the_roll
        failing = sprint_repo
        allow(failing).to receive(:by_id).and_return(nil)
        replace_component("repos.sprint_queries", failing)
        replace_component("tasks.repos.sprint_queries", failing)
      end

      def panel = page.find(".sprint-panel")

      def plan(*titles, done: 0)
        titles.each_with_index do |title, index|
          create(:task, :in_sprint, *([:done] if index < done), sprint_id: sprint.id, title:)
        end
      end

      def pool_note(key, **) = i18n.t(["ui.components.tasks.pools", key].join("."), **)

      def pull_under_sprint
        plan("Ship the panel")
        task = create(:task, title: "Email the accountant")
        get "/admin"
        form = pulls.find("form", visible: :all)
        fields = %w[origin pool].to_h { [it, form.find("[name='#{it}']", visible: :all).value] }
        post form[:action], _csrf_token: admin_csrf_token, **fields
        task
      end

      def pulls = panel.find(".task-planner-pull", visible: :all)

      def sprint = @sprint ||= create(:sprint, sprint_date: today)

      def sprint_repo = Tasks::Slice["repos.sprint_queries"]

      def start(title) = task_repo.in_sprint(sprint.id).find { it.title == title }.then { start_task(it) }

      def start_task(task) = Tasks::Slice["repos.task_mutations"].update(task.id, status: "in_progress")

      def task_repo = Tasks::Slice["repos.task_queries"]

      def words(key, **) = i18n.t(["ui.views.today.show", key].join("."), **)

      it "puts the day and time over the headline" do
        get "/admin"
        clock = Blog::TimeZone.local(Time.now).strftime("%H:%M")

        expect(page).to have_css(".page-head-kicker", exact_text: "#{today.strftime('%A, %B %-d')} · #{clock}")
      end

      it "says nothing is planned for an empty sprint", :aggregate_failures do
        get "/admin"

        expect(page).to have_css(".page-head-title", exact_text: words("headline.empty"))
        expect(page).to have_css(".page-head-sub", exact_text: words("lede.empty"))
      end

      it "counts one thing left" do
        plan("Ship the panel", "Read the design", done: 1)
        get "/admin"

        expect(page).to have_css(".page-head-title", exact_text: words("headline.left", count: 1))
      end

      it "counts the things left" do
        plan("Ship the panel", "Read the design", "Email the accountant")
        get "/admin"

        expect(page).to have_css(".page-head-title", exact_text: words("headline.left", count: 3))
      end

      it "calls the sprint clear when everything is done", :aggregate_failures do
        plan("Ship the panel", "Read the design", done: 2)
        get "/admin"

        expect(page).to have_css(".page-head-title", exact_text: words("headline.clear"))
        expect(page).to have_css(".page-head-sub", exact_text: words("lede.clear", count: 2))
      end

      it "names what is up next" do
        plan("Ship the panel", "Read the design", done: 1)
        get "/admin"

        expect(page).to have_css(".page-head-sub", text: "Up next: Read the design")
      end

      it "says how much is done" do
        plan("Ship the panel", "Read the design", done: 1)
        get "/admin"

        expect(page.find(".page-head-sub").text).to end_with("1 of 2 done.")
      end

      it "names the task in progress before the rest" do
        plan("Ship the panel", "Read the design")
        start("Read the design")
        get "/admin"

        expect(page).to have_css(".page-head-sub", text: "You're in the middle of Read the design")
      end

      it "says how long the lead task has carried over" do
        create(:task, :in_sprint, sprint_id: sprint.id, title: "Ship the panel", carried_count: 2)
        get "/admin"

        expect(page).to have_css(".page-head-sub", text: "Up next: Ship the panel, carried over 2 days")
      end

      it "leaves a canceled task out of the open rows" do
        plan("Ship the panel", "Read the design")
        create(:task, :canceled, :in_sprint, sprint_id: sprint.id, title: "Dropped")
        get "/admin"

        titles = panel.all(".sprint-rows .task-title").map(&:text)

        expect(titles).to contain_exactly("Ship the panel", "Read the design")
      end

      it "leaves a canceled task out of what is left" do
        plan("Ship the panel", "Read the design")
        create(:task, :canceled, :in_sprint, sprint_id: sprint.id, title: "Dropped")
        get "/admin"

        expect(page).to have_css(".page-head-title", exact_text: words("headline.left", count: 2))
      end

      it "calls the sprint clear when what is left was canceled" do
        plan("Ship the panel", done: 1)
        create(:task, :canceled, :in_sprint, sprint_id: sprint.id)
        get "/admin"

        expect(page).to have_css(".page-head-title", exact_text: words("headline.clear"))
      end

      it "puts the panel first in the main column" do
        get "/admin"

        expect(page).to have_css(".g-main > .today-main > .sprint-panel:first-child")
      end

      it "titles the panel Today's sprint" do
        get "/admin"

        expect(panel).to have_css("h2.card-title", exact_text: "Today's sprint")
      end

      it "ends each task's buttons with a pen that edits it and comes back to Today", :aggregate_failures do
        task = create(:task, :in_sprint, sprint_id: sprint.id)
        get "/admin"
        pen = panel.find(".task .task-acts > :last-child")

        expect(pen).to match_css("a[data-task-open-edit][aria-label='Edit']")
        expect(pen["href"]).to eq("/admin/tasks/#{task.id}/edit?filter=today&origin=today")
      end

      it "lists the open tasks" do
        plan("Ship the panel", "Read the design", done: 1)
        get "/admin"

        expect(panel.all(".sprint-rows .task-title").map(&:text)).to eq(["Read the design"])
      end

      it "folds what is done today away under its count", :aggregate_failures do
        plan("Ship the panel", "Read the design", done: 1)
        get "/admin"
        done = panel.find("details.today-more:not([open])", text: "done today")

        expect(done.find("summary")).to have_text("1 done today")
        expect(done.all(".task-title", visible: :all).map { it.text(:all) }).to eq(["Ship the panel"])
      end

      it "sets the open tasks in the large row and what is done in the normal one", :aggregate_failures do
        plan("Ship the panel", "Read the design", done: 1)
        get "/admin"

        expect(panel.all(".sprint-rows .task.large .task-title").map(&:text)).to eq(["Read the design"])
        expect(panel).to have_no_css("details.today-more .task.large", visible: :all)
      end

      it "completes a task from its box" do
        plan("Ship the panel")
        get "/admin"
        form = panel.find(".task > form:has(button.task-box)")
        post form[:action], _csrf_token: admin_csrf_token, filter: "today", origin: "today"

        expect(task_repo.in_sprint(sprint.id).map(&:status)).to eq(["done"])
      end

      it "counts a task's comments in its meta line" do
        plan("Ship the panel")
        task = task_repo.in_sprint(sprint.id).first
        2.times { create(:task_comment, task_id: task.id) }
        get "/admin"

        expect(panel.find(".task-meta")).to have_css(".task-mark", exact_text: "2") { it.has_css?(".fa-comment") }
      end

      it "leaves the comment count off a task with none" do
        plan("Ship the panel")
        get "/admin"

        expect(panel.find(".task-meta")).to have_no_css(".fa-comment")
      end

      it "folds nothing away when nothing is done" do
        plan("Ship the panel")
        get "/admin"

        expect(panel).to have_no_css("details.today-more", text: "done today")
      end

      it "leads each open task with its key" do
        tasks = %w[Ship Read].map { create(:task, :in_sprint, sprint_id: sprint.id, title: it) }
        get "/admin"

        expect(panel.all(".record-key").map(&:text)).to match_array(tasks.map { "##{it.id}" })
      end

      it "fills the progress bar with the share that is done" do
        plan("Ship the panel", "Read the design", done: 1)
        get "/admin"

        expect(panel.find(".sprint-progress-fill", visible: :all)[:style]).to eq("width: 50%")
      end

      it "names the progress bar and its values" do
        plan("Ship the panel", "Read the design", done: 1)
        get "/admin"
        bar = panel.find("[role='progressbar']")

        expect(%w[aria-label aria-valuemin aria-valuemax aria-valuenow].map { bar[it] })
          .to eq(["Sprint progress", "0", "2", "1"])
      end

      it "draws no progress bar for an empty sprint" do
        get "/admin"

        expect(panel).to have_no_css("[role='progressbar']")
      end

      it "notes the count done beside the title" do
        plan("Ship the panel", "Read the design", done: 1)
        get "/admin"

        expect(panel).to have_css(".sprint-note", exact_text: "1 of 2 done")
      end

      it "counts what was finished when everything is done" do
        plan("Ship the panel", done: 1)
        get "/admin"

        expect(panel).to have_css(".empty", text: "1 finished")
      end

      it "offers no capture row beside the sprint's tasks" do
        plan("Ship the panel")
        get "/admin"

        expect(panel).to have_no_field("task[title]")
      end

      it "offers the pools under the sprint's tasks" do
        plan("Ship the panel")
        create(:task, title: "Email the accountant")
        get "/admin"

        expect(pulls).to have_css(".li-title", exact_text: "Email the accountant", visible: :all)
      end

      it "keeps Today when switching the pool under the sprint's tasks" do
        plan("Ship the panel")
        get "/admin"

        hrefs = panel.all(".seg-option", visible: :all).map { it["href"] }

        expect(hrefs).to eq(%w[next someday external].map { "/admin?pool=#{it}" })
      end

      it "adds a task pulled from the pools under the sprint's tasks to today's sprint" do
        task = pull_under_sprint

        expect(task_repo.in_sprint(sprint.id).map(&:id)).to contain_exactly(task.id, anything)
      end

      it "links a GitHub issue in the external pool under the sprint's tasks" do
        plan("Ship the panel")
        url = "https://github.com/aaronmallen/aaronmallen.me/issues/42"
        create(:task_source, task: create(:task, :external), url:)
        get "/admin", pool: "external"

        expect(pulls).to have_link("aaronmallen/aaronmallen.me#42", href: url, visible: :all)
      end

      it "links a Linear issue by its workspace in the external pool under the sprint's tasks" do
        plan("Ship the panel")
        url = "https://linear.app/acme/issue/ABC-123/ship-the-release"
        create(:task_source, task: create(:task, :external), provider: "linear", remote_id: "lin-1", url:)
        get "/admin", pool: "external"

        expect(pulls).to have_link("acme/ABC-123", href: url, visible: :all)
      end

      it "comes back to Today after pulling from the pools under the sprint's tasks" do
        pull_under_sprint

        expect(last_response.headers["location"]).to eq("/admin?pool=next")
      end

      it "comes back to the pool a task was pulled from" do
        task = create(:task, :someday)
        post "/admin/tasks/#{task.id}/move/today", _csrf_token: admin_csrf_token, origin: "today", pool: "someday"

        expect(last_response.headers["location"]).to eq("/admin?pool=someday")
      end

      it "folds the pools away under the sprint's tasks", :aggregate_failures do
        plan("Ship the panel")
        get "/admin"
        pull = panel.find("details.today-more", text: "Pull from a list")

        expect(pull[:open]).to be_nil
        expect(pull).to have_css(".task-planner-pull", visible: :all)
      end

      it "opens the pools when the sprint is empty" do
        get "/admin"

        expect(panel).to have_css("details.today-more[open] .task-planner-pull")
      end

      it "leads each pool row with its key" do
        task = create(:task, title: "Email the accountant")
        get "/admin"

        expect(panel.find(".task-planner-list .task-meta")).to have_css(".record-key", exact_text: "##{task.id}")
      end

      it "renders every pool and hides all but the chosen one" do
        get "/admin", pool: "external"

        expect(panel.all("[data-pool-panel]:not([hidden])", visible: :all).map { it["data-pool-panel"] })
          .to eq(%w[external])
      end

      it "says the sprint holds nothing" do
        get "/admin"

        expect(panel).to have_css(".empty", exact_text: i18n.t("ui.components.tasks.sprint_panel.empty"))
      end

      it "offers no capture row with an empty sprint" do
        get "/admin"

        expect(panel).to have_no_field("task[title]")
      end

      it "counts every pool an empty sprint can pull from" do
        create(:task, title: "Email the accountant")
        create(:task, :someday, title: "Learn Elixir")
        get "/admin"

        expect(panel.all(".seg-option").map(&:text)).to eq(["next · 1", "someday · 1", "external · 0"])
      end

      it "keeps Today when switching the pool" do
        get "/admin"

        expect(panel.all(".seg-option").map { it["href"] }).to eq(%w[next someday external].map { "/admin?pool=#{it}" })
      end

      it "pulls from someday when that pool is asked for" do
        create(:task, title: "Email the accountant")
        create(:task, :someday, title: "Learn Elixir")
        get "/admin", pool: "someday"

        expect(panel.all(".li-title").map(&:text)).to eq(["Learn Elixir"])
      end

      it "says which pool is empty" do
        get "/admin"

        expect(panel).to have_css(".empty", exact_text: pool_note("empty.next"))
      end

      it "comes back to Today after pulling a task in" do
        task = create(:task)
        post "/admin/tasks/#{task.id}/move/today", _csrf_token: admin_csrf_token, origin: "today"

        expect(last_response.headers["location"]).to eq("/admin")
      end

      it "links through to the tasks screen" do
        get "/admin"

        expect(panel).to have_css(".card-side a[href='/admin/tasks']", exact_text: "all tasks →")
      end

      it "offers Plan tomorrow on the upcoming tab" do
        get "/admin"

        expect(page).to have_link("Plan tomorrow", href: "/admin/tasks?filter=upcoming")
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

        expect(panel.all(".sprint-rows .task-title").map(&:text)).to eq(["Read the design"])
      end

      it "answers with a server error when the day's sprint cannot be rolled" do
        create(:task, :in_sprint, sprint_id: create(:sprint, sprint_date: today - 1).id)
        lose_the_roll
        get "/admin"

        expect(last_response.status).to eq(500)
      end

      it "offers the Create Task button, with a page to fall back on", :aggregate_failures do
        get "/admin"
        button = page.find(".page-head-actions a", text: "Create Task")

        expect(button["href"]).to eq("/admin/tasks/new?origin=today")
        expect(button["data-dialog-open"]).to eq("task-create")
      end

      it "puts the Create Task dialog on Today" do
        get "/admin"

        expect(dialog).to have_css("form[action='/admin/tasks']", visible: :all)
      end

      it "starts the dialog on today's list", :aggregate_failures do
        get "/admin"

        expect(dialog).to have_select("task[list]", selected: "today", visible: :all)
        expect(dialog).to have_field("origin", type: :hidden, with: "today")
      end

      it "writes a task from the dialog straight into today" do
        create_from_today("Ship the panel")

        expect(task_repo.in_sprint(sprint_repo.on(Blog::TimeZone.today).id).map(&:title)).to eq(["Ship the panel"])
      end

      it "comes back to Today after creating a task" do
        create_from_today("Ship the panel")

        expect(last_response.headers["location"]).to eq("/admin")
      end

      it "comes back to Today after finishing a task from the panel" do
        plan("Ship the panel")
        task = task_repo.in_sprint(sprint.id).first
        post "/admin/tasks/#{task.id}/complete", _csrf_token: admin_csrf_token, filter: "today", origin: "today"

        expect(last_response.headers["location"]).to eq("/admin")
      end

      it "says what is missing when a task from Today carries no title", :aggregate_failures do
        create_from_today("")

        expect(last_response.status).to eq(422)
        expect(page).to have_css(".field-error", text: i18n.t("ui.components.tasks.field_error.title.blank"))
      end

      it "keeps the way back to Today when a task from Today carries no title", :aggregate_failures do
        create_from_today("")
        form = page.find("main form.task-form")

        expect(form).to have_field("origin", type: :hidden, with: "today")
        expect(form).to have_select("task[list]", selected: "today")
      end
    end
  end
end
