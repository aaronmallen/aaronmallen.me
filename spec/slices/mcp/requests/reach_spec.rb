# frozen_string_literal: true

RSpec.describe "MCP reach", type: :request do
  def self.exempt
    {
      "admin.operations.build_activity_page" => "builds the admin's activity screen; read_activity reads the same feed",
      "admin.operations.build_navigation" => "builds the admin's menu",
      "admin.operations.build_person_editor" => "builds the admin's people editor; the MCP has no people tool",
      "admin.operations.build_post_editor" => "builds the admin's post editor; read_post and update_post cover a post",
      "admin.operations.build_post_preview" => "renders the admin editor's preview; read_post sends the body",
      "admin.operations.build_posts_page" => "builds the admin's posts screen; list_posts reads the same posts",
      "admin.operations.build_project_editor" => "builds the admin's project editor; save_project covers a project",
      "admin.operations.build_projects_page" => "builds the admin's projects screen; list_projects reads the same",
      "admin.operations.build_social_page" => "builds the admin's social screen; list_social_posts reads the same",
      "admin.operations.build_tags_page" => "builds the admin's tags screen; list_tags reads the same tags",
      "admin.operations.build_task_page" => "builds the admin's task page; read_task reads the same task",
      "admin.operations.build_tasks_page" => "builds the admin's tasks screen; list_tasks reads the same tasks",
      "admin.operations.count_network_lengths" => "counts characters as the admin types; compose checks the limits",
      "admin.operations.count_unread_messages" => "counts the admin menu's badge; list_messages reads the messages",
      "admin.operations.describe_social_post" => "words a social post for the admin's list",
      "admin.operations.end_sessions" => "signs the admin out everywhere; sign in stays out of the MCP",
      "admin.operations.find_over_limit_network" => "warns the admin; accept_suggestion_edits checks the limits",
      "admin.operations.list_activity_events" => "words the admin's activity screen; read_activity reads the feed",
      "admin.operations.list_networks" => "lists networks for the admin's pickers",
      "admin.operations.list_sections" => "lists the admin menu's sections",
      "admin.operations.list_social_accounts" => "lists the admin's accounts for its social screen",
      "admin.operations.preview_announcement" => "previews the admin's announcement; compose_announcement writes one",
      "admin.operations.review_social_edits" => "lays out edits for the admin; list_suggestions reads them",
      "admin.operations.sign_in" => "signs the admin in through GitHub; sign in stays out of the MCP",
      "admin.operations.summarize_analytics" => "builds the admin's analytics screen; read_analytics reads the same",
      "admin.operations.summarize_journal" => "builds the admin's journal tile; list_journal_entries reads the same",
      "admin.operations.summarize_sprint" => "builds the admin's sprint tile; read_current_sprint reads the same",
      "admin.operations.summarize_today" => "builds the admin's today screen; summarize_activity reads the same",
      "analytics.operations.hash_visitor" => "hashes a visitor as a request comes in",
      "analytics.operations.prune_analytics_events" => "a background job prunes old visits after the roll up",
      "analytics.operations.record_visit" => "records a visit as a reader's browser reports it",
      "analytics.operations.refresh_country_database" => "a background job refreshes the country database",
      "analytics.operations.roll_up_analytics" => "a background job rolls up the day's visits",
      "api.operations.authenticate" => "checks the API token on each API request",
      "api.operations.mint_token" => "the owner mints an API token in the admin, which no client should do",
      "api.operations.revoke_token" => "the owner revokes an API token in the admin, which no client should do",
      "contact.operations.create_message" => "a reader sends a message through the public form",
      "contact.operations.reap_spam_messages" => "a background job reaps old spam messages",
      "media.operations.upload_photo" => "the admin's Markdown editor uploads photos; MCP takes no uploads",
      "media.operations.sweep_photos" => "a background job sweeps photos nothing claimed",
      "mcp.operations.authenticate" => "OAuth: checks the token on each MCP request",
      "mcp.operations.authorize" => "OAuth: the owner grants a client in the browser",
      "mcp.operations.issue_token" => "OAuth: a client trades a code or a refresh token",
      "mcp.operations.issue_tokens" => "OAuth: mints the tokens issue_token hands out",
      "mcp.operations.reap_expired_credentials" => "a background job reaps expired OAuth codes and tokens",
      "mcp.operations.register_client" => "OAuth: a client registers itself",
      "mcp.operations.revoke_client" => "OAuth: the owner cuts off a client in the admin, which no client should do",
      "posts.operations.record_post_webmentions" => "the webmention delivery job records what it sent",
      "posts.operations.revise_edit_note" => "the admin fixes a note in the editor; #141 gives MCP no tool for it",
      "projects.operations.refresh_projects" => "a background job refreshes projects from GitHub",
      "public.operations.find_page" => "checks that a visit names a real page as a reader's browser reports it",
      "public.operations.find_visitor_address" => "reads a visitor's address off a request",
      "public.operations.render_atom_feed" => "renders the public Atom feed",
      "public.operations.version_atom_feed" => "dates and tags the public Atom feed for a reader polling again",
      "record.operations.backfill_repo_commits" => "a background job walks a repository's history",
      "record.operations.import_commits" => "the import job runs it; import_commits queues that job",
      "record.operations.reap_sync_states" => "a background job reaps old sync states",
      "record.operations.record_country_sync_outcome" => "the country database job records how it went",
      "record.operations.record_issue_sync_outcome" => "the issue sync job records how it went",
      "record.operations.record_linear_issue_sync_outcome" => "the Linear issue sync job records how it went",
      "record.operations.record_projects_sync_outcome" => "the projects job records how it went",
      "record.operations.record_rollup_sync_outcome" => "the roll up job records how it went",
      "record.operations.record_sync_outcome" => "each sync job records how it went; read_sync_state reads it",
      "record.operations.store_commits" => "the import and backfill jobs store the commits they fetch",
      "social.operations.delete_person" => "the admin removes a person; the MCP has no people tool",
      "social.operations.deliver_social_post" => "a background job delivers what send_social_post queues",
      "social.operations.queue_syndication" => "the syndication job runs it after publish_post publishes a post",
      "social.operations.reap_webmention_receipts" => "a background job reaps old webmention receipts",
      "social.operations.receive_webmention" => "another site sends a webmention to the public endpoint",
      "social.operations.refresh_social_engagement" => "a background job refreshes likes and replies",
      "social.operations.save_person" => "the admin fills in the people directory; the MCP has no people tool",
      "social.operations.send_webmentions" => "a background job sends a post's webmentions after it saves",
      "social.operations.verify_webmention" => "a background job checks a received webmention's source",
      "tasks.operations.delete_task_comment" => "the admin deletes a comment; spec #65 gives the MCP only an add tool",
      "tasks.operations.edit_task_comment" => "the admin edits a comment; spec #65 gives the MCP only an add tool",
      "tasks.operations.place_task" => "the admin's drag places a task; reorder_task moves one a place up or down",
      "tasks.operations.queue_issue_sync" => "the admin's sync button queues the issue sync job",
      "tasks.operations.sync_issues" => "a background job syncs the GitHub issues assigned to me",
    }
  end

  def article = @article ||= create(:post, :published, published_at: at(9))

  def at(hour) = Blog::TimeZone.local_time(today.year, today.month, today.day, hour, 0)

  def exempt = self.class.exempt

  def operations
    Hanami.app.slices.to_a.flat_map do |slice|
      Dir[slice.root.join("operations", "**", "*.rb")].map do |path|
        "#{slice.slice_name}.operations.#{File.basename(path, '.rb')}"
      end
    end
  end

  def reached(object = MCP::Slice["protocol.handler"], seen = Set.new)
    object.instance_variables.map { object.instance_variable_get(it) }.each do |dependency|
      next unless walked?(dependency) && seen.add?(dependency.class)

      reached(dependency, seen)
    end
    seen
  end

  def reached_keys
    classes = reached
    operations.select { classes.include?(resolve(it).class) }
  end

  def resolve(key)
    slice, local = key.split(".", 2)
    Hanami.app.slices[slice.to_sym][local]
  end

  def seed(kind)
    seeder = :"seed_#{kind}"
    public_send(seeder) if respond_to?(seeder)
  end

  def seed_comment = create(:task_comment, created_at: at(10))

  def seed_commit = create(:commit, commit_date: today)

  def seed_journal = create(:journal_entry, entry_date: today)

  def seed_post = article

  def seed_project = create(:project)

  def seed_social = create(:social_post, :posted, posted_at: at(12))

  def seed_sprint = create(:sprint, sprint_date: today)

  def seed_suggestion = Suggestions::Slice["repos.suggestion_repo"].replace_for_post(article.id, [typo])

  def seed_task = create(:task, :done, completed_at: at(16))

  def seed_webmention = create(:webmention, :approved, post_id: article.id, received_at: at(8))

  def today = Blog::TimeZone.today

  def typo = { original: "teh", replacement: "the", reason: "typo" }

  def walked?(dependency) = dependency.class.name.to_s.match?(/::(Endpoints|Operations)::/)

  it "reaches every operation from a tool unless the operation is exempt" do
    unreached = operations - reached_keys - exempt.keys

    expect(unreached).to be_empty, "no tool reaches these, and none is exempt:\n#{unreached.join("\n")}"
  end

  it "exempts only operations a slice holds" do
    expect(exempt.keys - operations).to be_empty
  end

  it "exempts no operation a tool reaches" do
    expect(exempt.keys & reached_keys).to be_empty
  end

  it "gives every exempt operation a reason" do
    expect(exempt.select { |_, reason| reason.to_s.strip.empty? }.keys).to be_empty
  end

  Blog::Types::ActivityKind.each_value do |kind|
    it "serves the #{kind} kind through read_activity" do
      seed(kind)
      served = mcp_answer("read_activity", from: (today - 1).iso8601, to: today.iso8601, kinds: [kind])

      expect(served.fetch("activity").map { it.fetch("kind") }).to include(kind)
    end
  end
end
