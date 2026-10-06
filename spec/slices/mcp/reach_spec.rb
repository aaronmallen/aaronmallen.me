# frozen_string_literal: true

RSpec.describe "MCP reach", type: :app do
  def self.exempt
    {
      "admin.operations.build_activity_page" => "builds the admin's activity screen; read_activity reads the same feed",
      "admin.operations.build_calendar_page" => "builds the admin's calendar screen; list_calendar reads the same days",
      "admin.operations.build_commit_page" => "builds the admin's commit page; read_commit reads the same commit",
      "admin.operations.build_decision_editor" => "builds the admin's decision editor; edit_decision covers a decision",
      "admin.operations.build_decision_page" => "builds the admin's decision page; read_decision reads it",
      "admin.operations.build_navigation" => "builds the admin's menu",
      "admin.operations.build_person_editor" => "builds the admin's people editor; save_person covers a person",
      "admin.operations.build_post_analytics" => "builds the admin's post analytics page; read_analytics reads a path",
      "admin.operations.build_post_editor" => "builds the admin's post editor; read_post and update_post cover a post",
      "admin.operations.build_post_preview" => "renders the admin editor's preview; read_post sends the body",
      "admin.operations.build_posts_page" => "builds the admin's posts screen; list_posts reads the same posts",
      "admin.operations.build_project_editor" => "builds the admin's project editor; save_project covers a project",
      "admin.operations.build_projects_page" => "builds the admin's projects screen; list_projects reads the same",
      "admin.operations.build_review_page" => "builds the admin's review screen; read_review reads the same review",
      "admin.operations.build_search_page" => "builds the admin's search screen; the search tool runs the same search",
      "admin.operations.build_social_page" => "builds the admin's social screen; list_social_posts reads the same",
      "admin.operations.build_tags_page" => "builds the admin's tags screen; list_tags reads the same tags",
      "admin.operations.build_task_page" => "builds the admin's task page; read_task reads the same task",
      "admin.operations.build_time_page" => "builds the admin's time screen; read_time_report reads the same",
      "admin.operations.build_tasks_page" => "builds the admin's tasks screen; list_tasks reads the same tasks",
      "admin.operations.count_network_lengths" => "counts characters as the admin types; compose checks the limits",
      "admin.operations.describe_social_post" => "words a social post for the admin's list",
      "admin.operations.end_sessions" => "signs the admin out everywhere; sign in stays out of the MCP",
      "admin.operations.find_over_limit_network" => "warns the admin; accept_suggestion_edits checks the limits",
      "admin.operations.link_search_hit" => "links a search hit to its admin screen; MCP tools answer with ids",
      "admin.operations.list_actions" => "lists the admin palette's actions",
      "admin.operations.list_activity_events" => "words the admin's activity screen; read_activity reads the feed",
      "admin.operations.list_networks" => "lists networks for the admin's pickers",
      "admin.operations.list_palette_saved_views" => "lists views for the admin palette; list_saved_views reads them",
      "admin.operations.list_record_links" => "fills the admin's Linked section; list_links reads the same links",
      "admin.operations.list_saved_views" => "lists a screen's saved views in the admin; list_saved_views reads them",
      "admin.operations.list_sections" => "lists the admin menu's sections",
      "admin.operations.list_social_accounts" => "lists the admin's accounts for its social screen",
      "admin.operations.open_journal_entry" => "opens an entry on the admin's journal; read_journal_entry reads it",
      "admin.operations.preview_announcement" => "previews the admin's announcement; compose_announcement writes one",
      "admin.operations.search_palette" => "groups search hits for the admin palette; the search tool finds them",
      "admin.operations.review_social_edits" => "lays out edits for the admin; list_suggestions reads them",
      "admin.operations.sign_in" => "signs the admin in through GitHub; sign in stays out of the MCP",
      "admin.operations.summarize_analytics" => "builds the admin's analytics screen; read_analytics reads the same",
      "admin.operations.summarize_journal" => "builds the admin's journal tile; list_journal_entries reads the same",
      "admin.operations.summarize_sprint" => "builds the admin's sprint tile; read_current_sprint reads the same",
      "admin.operations.summarize_today" => "builds the admin's today screen; summarize_activity reads the same",
      "analytics.operations.hash_reader" => "hashes a post's reader as a view comes in",
      "analytics.operations.hash_visitor" => "hashes a visitor as a request comes in",
      "analytics.operations.prune_analytics_events" => "a background job prunes old visits after the roll up",
      "analytics.operations.record_feed_fetch" => "counts a feed fetch as a feed reader polls",
      "analytics.operations.record_visit" => "records a visit as a reader's browser reports it",
      "analytics.operations.refresh_country_database" => "a background job refreshes the country database",
      "analytics.operations.roll_up_analytics" => "a background job rolls up the day's visits",
      "analytics.operations.save_reader_counts" => "a background job saves each post's final reader count",
      "api.operations.authenticate" => "checks the API token on each API request",
      "api.operations.build_document" => "builds the OpenAPI document the API serves to its clients",
      "api.operations.mint_token" => "the owner mints an API token in the admin, which no client should do",
      "api.operations.revoke_token" => "the owner revokes an API token in the admin, which no client should do",
      "backups.operations.back_up_database" => "a background job dumps the database each night",
      "contact.operations.create_message" => "a reader sends a message through the public form",
      "contact.operations.reap_spam_messages" => "a background job reaps old spam messages",
      "media.operations.sweep_photos" => "a background job sweeps photos nothing claimed",
      "mcp.operations.authenticate" => "OAuth: checks the token on each MCP request",
      "mcp.operations.authorize" => "OAuth: the owner grants a client in the browser",
      "mcp.operations.issue_token" => "OAuth: a client trades a code or a refresh token",
      "mcp.operations.issue_tokens" => "OAuth: mints the tokens issue_token hands out",
      "mcp.operations.reap_expired_credentials" => "a background job reaps spent OAuth codes, tokens and idle clients",
      "mcp.operations.register_client" => "OAuth: a client registers itself",
      "mcp.operations.revoke_client" => "OAuth: the owner cuts off a client in the admin, which no client should do",
      "posts.operations.move_post" => "the admin's calendar moves a post a day; update_post sets any time",
      "posts.operations.record_post_webmentions" => "the webmention delivery job records what it sent",
      "projects.operations.refresh_projects" => "a background job refreshes projects from GitHub",
      "public.operations.check_contact_stamp" => "checks the contact form's stamp as a reader sends it",
      "public.operations.find_page" => "checks that a visit names a real page as a reader's browser reports it",
      "public.operations.find_visitor_address" => "reads a visitor's address off a request",
      "public.operations.issue_contact_stamp" => "stamps the contact form as a reader loads it",
      "public.operations.render_atom_feed" => "renders the public Atom feed",
      "public.operations.version_atom_feed" => "dates and tags the public Atom feed for a reader polling again",
      "record.operations.backfill_repo_commits" => "a background job walks a repository's history",
      "record.operations.import_commits" => "the import job runs it; import_commits queues that job",
      "record.operations.reap_sync_states" => "a background job reaps old sync states",
      "record.operations.record_backup_sync_outcome" => "the backups job records how it went",
      "record.operations.record_country_sync_outcome" => "the country database job records how it went",
      "record.operations.record_issue_sync_outcome" => "the issue sync job records how it went",
      "record.operations.record_linear_issue_sync_outcome" => "the Linear issue sync job records how it went",
      "record.operations.record_projects_sync_outcome" => "the projects job records how it went",
      "record.operations.record_rollup_sync_outcome" => "the roll up job records how it went",
      "record.operations.record_sync_outcome" => "each sync job records how it went; read_sync_state reads it",
      "record.operations.store_commits" => "the backfill job stores the commits it fetches",
      "saved_views.operations.rename_saved_view" => "the admin renames a view; update_saved_view does it in one step",
      "social.operations.deliver_social_post" => "a background job delivers what send_social_post queues",
      "social.operations.move_social_post" => "the admin's calendar moves one a day; send_social_post sets any time",
      "social.operations.queue_syndication" => "the syndication job runs it after publish_post publishes a post",
      "social.operations.reap_webmention_receipts" => "a background job reaps old webmention receipts",
      "social.operations.receive_webmention" => "another site sends a webmention to the public endpoint",
      "social.operations.refresh_social_engagement" => "a background job refreshes likes and replies",
      "social.operations.send_webmentions" => "a background job sends a post's webmentions after it saves",
      "social.operations.verify_webmention" => "a background job checks a received webmention's source",
      "tasks.operations.credit_agents" => "a background job runs it when an imported commit names an agent",
      "tasks.operations.sync_comments" => "the issue sync runs it for each issue it follows",
      "tasks.operations.sync_issues" => "a background job syncs the GitHub issues assigned to me",
    }
  end

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
end
