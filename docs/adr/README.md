# Architecture decision records

Each record holds one decision: what we chose, why, and what it costs. Read [writing ADRs] before you add
one.

| # | Title | Status | Created |
| --- | --- | --- | --- |
| [0001][0001] | Split the app into slices by feature | ![Active][active] | 2026-09-28 |
| [0002][0002] | Hold app/ and the slices to Hanami's own directories | ![Active][active] | 2026-09-28 |
| [0003][0003] | Reach another slice only through its exports | ![Active][active] | 2026-09-28 |
| [0004][0004] | Hand every slice the app's routes helper through a prepend | ![Active][active] | 2026-09-28 |
| [0005][0005] | Run every tool through a mise task and pin tool versions in mise.lock | ![Active][active] | 2026-09-28 |
| [0006][0006] | Run the site on a Raspberry Pi behind a Cloudflare Tunnel, with its data on the NAS | ![Active][active] | 2026-09-28 |
| [0007][0007] | Read settings from the environment's file, then default.yml, then the environment | ![Active][active] | 2026-09-28 |
| [0008][0008] | Build the database URL from settings, in a db provider in every slice | ![Active][active] | 2026-09-28 |
| [0009][0009] | Register every service client, with or without its credentials | ![Active][active] | 2026-09-28 |
| [0010][0010] | Configure Honeybadger from settings in a provider, not from honeybadger.yml | ![Active][active] | 2026-09-28 |
| [0011][0011] | Run jobs on Sidekiq in one worker that boots the app | ![Active][active] | 2026-09-28 |
| [0012][0012] | Never retry a scheduled job, and make its next run catch up | ![Active][active] | 2026-09-28 |
| [0013][0013] | Read the visitor address from one proxy header, and only from a trusted peer | ![Active][active] | 2026-09-28 |
| [0014][0014] | Build every absolute URL from the site setting | ![Active][active] | 2026-09-28 |
| [0015][0015] | Type a closed set as a Postgres enum and a format as a domain | ![Active][active] | 2026-09-28 |
| [0016][0016] | Keep only dry types in Blog::Types, and only unowned values in Blog::Constants | ![Active][active] | 2026-09-28 |
| [0017][0017] | Enforce rules over stored state in Postgres, not in contracts | ![Active][active] | 2026-09-28 |
| [0018][0018] | Run the site on one time zone, written into the schema as a literal | ![Active][active] | 2026-09-28 |
| [0019][0019] | Open every transaction as a savepoint | ![Active][active] | 2026-09-28 |
| [0020][0020] | Keep locks, throttles and claims in Postgres, not Redis | ![Active][active] | 2026-09-28 |
| [0021][0021] | Let SQL read another slice's tables, never write them | ![Active][active] | 2026-09-28 |
| [0022][0022] | Declare the tags relation in every slice that tags | ![Active][active] | 2026-09-28 |
| [0023][0023] | Sign in with GitHub OAuth for one operator | ![Active][active] | 2026-09-28 |
| [0024][0024] | Mount the session cookie in admin and mcp alone, and let public read it by hand | ![Active][active] | 2026-09-28 |
| [0025][0025] | Inherit Blog::Operation only in a class that can refuse or steps a Result | ![Active][active] | 2026-09-28 |
| [0026][0026] | Coerce a param in the action, validate it in a contract | ![Active][active] | 2026-09-28 |
| [0027][0027] | Fail a contract with a code and let the view word it | ![Active][active] | 2026-09-28 |
| [0028][0028] | Render views with phlex-hanami instead of hanami-view | ![Active][active] | 2026-09-28 |
| [0029][0029] | Build a view model in structs/ as a Ruby Data class | ![Active][active] | 2026-09-28 |
| [0030][0030] | Keep a component in the slice that draws it | ![Active][active] | 2026-09-28 |
| [0031][0031] | Give each element one class named for what it is, defined as a Tailwind utility | ![Active][active] | 2026-09-28 |
| [0032][0032] | Keep the theme in a site_theme cookie the browser sets, and draw it with light-dark() | ![Active][active] | 2026-09-28 |
| [0033][0033] | Draw every icon as a Font Awesome Free class | ![Active][active] | 2026-09-28 |
| [0034][0034] | Hold every page to a 1040px column and prose to its own measure | ![Active][active] | 2026-09-28 |
| [0035][0035] | Test the app only through requests, the browser, jobs and MCP | ![Active][active] | 2026-09-28 |
| [0036][0036] | Check every route with axe-core in the browser suite | ![Active][active] | 2026-09-28 |
| [0037][0037] | Give every public page an h1, hidden where the design draws none | ![Active][active] | 2026-09-28 |
| [0038][0038] | Keep the schedule and the live time in one published_at, and never unpublish | ![Active][active] | 2026-09-28 |
| [0039][0039] | Keep the announcement on the post and send it once | ![Active][active] | 2026-09-28 |
| [0040][0040] | Send a social post to each network on its own, from that network's delivery row | ![Active][active] | 2026-09-28 |
| [0041][0041] | Generate author_domain in Postgres, not in Ruby | ![Active][active] | 2026-09-28 |
| [0042][0042] | Trust a webmention author by exact URL, on their own host | ![Superseded][superseded-0107] | 2026-09-28 |
| [0043][0043] | Guard the contact form with a honeypot and a daily hash, not a cookie | ![Active][active] | 2026-09-28 |
| [0044][0044] | Replace the contact form with its answer, on a page load | ![Active][active] | 2026-09-28 |
| [0045][0045] | Count visitors with a daily hash and no cookies | ![Superseded][superseded-0102] | 2026-09-28 |
| [0046][0046] | Let the garbage collector take a superseded MaxMind reader | ![Active][active] | 2026-09-28 |
| [0047][0047] | Keep every sync's state in record's sync_states table, keyed by kind, sync and repo | ![Active][active] | 2026-09-28 |
| [0048][0048] | Import commits over GitHub's GraphQL API and keep REST for two project reads | ![Superseded][superseded-0069] | 2026-09-28 |
| [0049][0049] | Walk each repo's commits in one job that queues itself | ![Active][active] | 2026-09-28 |
| [0050][0050] | Derive Today from sprint membership | ![Active][active] | 2026-09-28 |
| [0051][0051] | Store a task link once and derive its reverse on read | ![Active][active] | 2026-09-28 |
| [0052][0052] | Read activity through one view across every content kind | ![Active][active] | 2026-09-28 |
| [0053][0053] | Navigate the admin through a command palette, not a tab strip | ![Active][active] | 2026-09-28 |
| [0054][0054] | Run every admin screen on a phone | ![Active][active] | 2026-09-28 |
| [0055][0055] | Make every admin write a plain form POST that scripts only add to | ![Active][active] | 2026-09-28 |
| [0056][0056] | Serve MCP from our own OAuth 2.1 server and the official Ruby SDK | ![Active][active] | 2026-09-28 |
| [0057][0057] | Put the mcp slice inside the SDK's own MCP module | ![Active][active] | 2026-09-28 |
| [0058][0058] | Serve MCP as one stateless POST action | ![Active][active] | 2026-09-28 |
| [0059][0059] | Gate an MCP client on the operator's consent, not on registration | ![Active][active] | 2026-09-28 |
| [0060][0060] | Rotate a refresh token on each use and revoke a client's tokens on replay | ![Active][active] | 2026-09-28 |
| [0061][0061] | Narrow a requested scope to known names and withhold every tool a token lacks | ![Active][active] | 2026-09-28 |
| [0062][0062] | Send every kind in the activity feed to a client holding read | ![Active][active] | 2026-09-28 |
| [0063][0063] | Apply a suggested edit only where its text appears once, under its owner's lock | ![Active][active] | 2026-09-28 |
| [0064][0064] | Close a task as done or canceled under one completed_at | ![Active][active] | 2026-09-28 |
| [0065][0065] | Label a task with tags alone | ![Active][active] | 2026-09-28 |
| [0066][0066] | Keep an imported task's origin in a task_sources table | ![Active][active] | 2026-09-28 |
| [0067][0067] | Park an imported task on an external list | ![Active][active] | 2026-09-28 |
| [0068][0068] | Follow a change in an issue's state, not the state itself | ![Active][active] | 2026-09-29 |
| [0069][0069] | Read GitHub over GraphQL, and keep REST for project reads and the issue move check | ![Active][active] | 2026-09-29 |
| [0070][0070] | Share one issue sync across providers, and run each provider as its own job | ![Active][active] | 2026-09-29 |
| [0071][0071] | Load a task's read and edit pages into dialogs with fetch | ![Active][active] | 2026-09-29 |
| [0072][0072] | Render raw HTML in task notes through the sanitize gem | ![Active][active] | 2026-09-29 |
| [0073][0073] | Read the app version from the git tag at boot | ![Active][active] | 2026-09-29 |
| [0074][0074] | Split tags into a public and a private scope | ![Active][active] | 2026-09-29 |
| [0075][0075] | Keep local and synced task comments in one table keyed by remote id | ![Active][active] | 2026-09-29 |
| [0076][0076] | Page flat lists by number and day-grouped lists by whole day | ![Active][active] | 2026-09-29 |
| [0077][0077] | Tag an imported task from its labels only on import | ![Active][active] | 2026-09-29 |
| [0078][0078] | Ignore a webmention through a new status that is neutral for trust | ![Active][active] | 2026-09-30 |
| [0079][0079] | Store a mention as a token expanded at delivery | ![Active][active] | 2026-09-30 |
| [0080][0080] | Store photos in an S3 store and serve them through the site | ![Active][active] | 2026-09-30 |
| [0081][0081] | Process every upload with libvips on the server | ![Active][active] | 2026-09-30 |
| [0082][0082] | Tie a photo to the records whose Markdown points to it | ![Active][active] | 2026-09-30 |
| [0083][0083] | Upload photos by fetch from the Markdown editor | ![Active][active] | 2026-09-30 |
| [0084][0084] | Keep edit notes in a post_edits table and require one under the post's lock | ![Active][active] | 2026-09-30 |
| [0085][0085] | Reorder tasks by drag and save the order through fetch | ![Active][active] | 2026-10-01 |
| [0086][0086] | Serve a JSON API behind long-lived tokens minted in the admin | ![Active][active] | 2026-10-01 |
| [0087][0087] | Widen what analytics keeps with a monthly hash, and roll up each page's breakdowns | ![Active][active] | 2026-10-01 |
| [0088][0088] | Hold the layer the API and MCP share in the api slice, and call it in process | ![Active][active] | 2026-10-01 |
| [0089][0089] | Build every API response with Alba serializers | ![Active][active] | 2026-10-01 |
| [0090][0090] | Let Cloudflare keep anonymous public pages for five minutes | ![Active][active] | 2026-10-01 |
| [0091][0091] | Fetch the palette's open tasks from a session-only admin route when it opens | ![Superseded][superseded-0096] | 2026-10-01 |
| [0092][0092] | Keep task history in task_events and a task_timeline view | ![Active][active] | 2026-10-03 |
| [0093][0093] | Link any two records through one record_links table in a links slice | ![Active][active] | 2026-10-03 |
| [0094][0094] | Keep a seen_at on task_sources, and merge the inbox in the api slice | ![Active][active] | 2026-10-03 |
| [0095][0095] | Build the stalled list in the activity slice and keep snoozes in attention_snoozes | ![Active][active] | 2026-10-03 |
| [0096][0096] | Search every kind through tsvector columns and one view in a search slice | ![Active][active] | 2026-10-03 |
| [0097][0097] | Keep saved views in their own slice with a screen enum and jsonb filters | ![Active][active] | 2026-10-03 |
| [0098][0098] | Run each bulk action as one operation per list, in one transaction | ![Active][active] | 2026-10-03 |
| [0099][0099] | Keep decision logs in a decisions slice with decision_events and a decision_timeline view | ![Active][active] | 2026-10-03 |
| [0100][0100] | Build the review in one activity query that admin and api share | ![Active][active] | 2026-10-03 |
| [0101][0101] | Bind every admin key through one key map that reads keys from the markup | ![Active][active] | 2026-10-03 |
| [0102][0102] | Count each post's unique readers with an undated hash kept for 12 months | ![Active][active] | 2026-10-03 |
| [0103][0103] | Tag an imported task from repo rules on import, and once when a rule is created | ![Active][active] | 2026-10-03 |
| [0104][0104] | Version releases with CalVer, back to the first release | ![Active][active] | 2026-10-03 |
| [0105][0105] | Dump the database nightly to a private backups bucket and keep the newest 7 | ![Active][active] | 2026-10-03 |
| [0106][0106] | Count feed fetches on the server, and capture outbound clicks from the beacon | ![Superseded][superseded-0110] | 2026-10-03 |
| [0107][0107] | Trust a webmention author only under their URL, and a whole host only when marked | ![Active][active] | 2026-10-04 |
| [0108][0108] | Show remote images in imported markdown as links | ![Active][active] | 2026-10-04 |
| [0109][0109] | Let Cloudflare keep a published photo for one day | ![Active][active] | 2026-10-04 |
| [0110][0110] | Take subscriber counts only from the feed aggregators we name | ![Active][active] | 2026-10-04 |
| [0111][0111] | Send Strict-Transport-Security from the app, for the apex alone | ![Active][active] | 2026-10-04 |
| [0112][0112] | Give every tag rule a provider, and match Linear issues by workspace and team | ![Active][active] | 2026-10-06 |

[0001]: 0001-split-the-app-into-slices-by-feature.md
[0002]: 0002-hold-app-and-the-slices-to-hanamis-own-directories.md
[0003]: 0003-reach-another-slice-only-through-its-exports.md
[0004]: 0004-hand-every-slice-the-apps-routes-helper-through-a-prepend.md
[0005]: 0005-run-every-tool-through-a-mise-task-and-pin-tool-versions-in-mise-lock.md
[0006]: 0006-run-the-site-on-a-raspberry-pi-behind-a-cloudflare-tunnel-with-its-data-on-the-nas.md
[0007]: 0007-read-settings-from-the-environments-file-then-default-yml-then-the-environment.md
[0008]: 0008-build-the-database-url-from-settings-in-a-db-provider-in-every-slice.md
[0009]: 0009-register-every-service-client-with-or-without-its-credentials.md
[0010]: 0010-configure-honeybadger-from-settings-in-a-provider-not-from-honeybadger-yml.md
[0011]: 0011-run-jobs-on-sidekiq-in-one-worker-that-boots-the-app.md
[0012]: 0012-never-retry-a-scheduled-job-and-make-its-next-run-catch-up.md
[0013]: 0013-read-the-visitor-address-from-one-proxy-header-and-only-from-a-trusted-peer.md
[0014]: 0014-build-every-absolute-url-from-the-site-setting.md
[0015]: 0015-type-a-closed-set-as-a-postgres-enum-and-a-format-as-a-domain.md
[0016]: 0016-keep-only-dry-types-in-blog-types-and-only-unowned-values-in-blog-constants.md
[0017]: 0017-enforce-rules-over-stored-state-in-postgres-not-in-contracts.md
[0018]: 0018-run-the-site-on-one-time-zone-written-into-the-schema-as-a-literal.md
[0019]: 0019-open-every-transaction-as-a-savepoint.md
[0020]: 0020-keep-locks-throttles-and-claims-in-postgres-not-redis.md
[0021]: 0021-let-sql-read-another-slices-tables-never-write-them.md
[0022]: 0022-declare-the-tags-relation-in-every-slice-that-tags.md
[0023]: 0023-sign-in-with-github-oauth-for-one-operator.md
[0024]: 0024-mount-the-session-cookie-in-admin-and-mcp-alone-and-let-public-read-it-by-hand.md
[0025]: 0025-inherit-blog-operation-only-in-a-class-that-can-refuse-or-steps-a-result.md
[0026]: 0026-coerce-a-param-in-the-action-validate-it-in-a-contract.md
[0027]: 0027-fail-a-contract-with-a-code-and-let-the-view-word-it.md
[0028]: 0028-render-views-with-phlex-hanami-instead-of-hanami-view.md
[0029]: 0029-build-a-view-model-in-structs-as-a-ruby-data-class.md
[0030]: 0030-keep-a-component-in-the-slice-that-draws-it.md
[0031]: 0031-give-each-element-one-class-named-for-what-it-is-defined-as-a-tailwind-utility.md
[0032]: 0032-keep-the-theme-in-a-site-theme-cookie-the-browser-sets-and-draw-it-with-light-dark.md
[0033]: 0033-draw-every-icon-as-a-font-awesome-free-class.md
[0034]: 0034-hold-every-page-to-a-1040px-column-and-prose-to-its-own-measure.md
[0035]: 0035-test-the-app-only-through-requests-the-browser-jobs-and-mcp.md
[0036]: 0036-check-every-route-with-axe-core-in-the-browser-suite.md
[0037]: 0037-give-every-public-page-an-h1-hidden-where-the-design-draws-none.md
[0038]: 0038-keep-the-schedule-and-the-live-time-in-one-published-at-and-never-unpublish.md
[0039]: 0039-keep-the-announcement-on-the-post-and-send-it-once.md
[0040]: 0040-send-a-social-post-to-each-network-on-its-own-from-that-networks-delivery-row.md
[0041]: 0041-generate-author-domain-in-postgres-not-in-ruby.md
[0042]: 0042-trust-a-webmention-author-by-exact-url-on-their-own-host.md
[0043]: 0043-guard-the-contact-form-with-a-honeypot-and-a-daily-hash-not-a-cookie.md
[0044]: 0044-replace-the-contact-form-with-its-answer-on-a-page-load.md
[0045]: 0045-count-visitors-with-a-daily-hash-and-no-cookies.md
[0046]: 0046-let-the-garbage-collector-take-a-superseded-maxmind-reader.md
[0047]: 0047-keep-every-syncs-state-in-records-sync-states-table-keyed-by-kind-sync-and-repo.md
[0048]: 0048-import-commits-over-githubs-graphql-api-and-keep-rest-for-two-project-reads.md
[0049]: 0049-walk-each-repos-commits-in-one-job-that-queues-itself.md
[0050]: 0050-derive-today-from-sprint-membership.md
[0051]: 0051-store-a-task-link-once-and-derive-its-reverse-on-read.md
[0052]: 0052-read-activity-through-one-view-across-every-content-kind.md
[0053]: 0053-navigate-the-admin-through-a-command-palette-not-a-tab-strip.md
[0054]: 0054-run-every-admin-screen-on-a-phone.md
[0055]: 0055-make-every-admin-write-a-plain-form-post-that-scripts-only-add-to.md
[0056]: 0056-serve-mcp-from-our-own-oauth-2-1-server-and-the-official-ruby-sdk.md
[0057]: 0057-put-the-mcp-slice-inside-the-sdks-own-mcp-module.md
[0058]: 0058-serve-mcp-as-one-stateless-post-action.md
[0059]: 0059-gate-an-mcp-client-on-the-operators-consent-not-on-registration.md
[0060]: 0060-rotate-a-refresh-token-on-each-use-and-revoke-a-clients-tokens-on-replay.md
[0061]: 0061-narrow-a-requested-scope-to-known-names-and-withhold-every-tool-a-token-lacks.md
[0062]: 0062-send-every-kind-in-the-activity-feed-to-a-client-holding-read.md
[0063]: 0063-apply-a-suggested-edit-only-where-its-text-appears-once-under-its-owners-lock.md
[0064]: 0064-close-a-task-as-done-or-canceled-under-one-completed-at.md
[0065]: 0065-label-a-task-with-tags-alone.md
[0066]: 0066-keep-an-imported-tasks-origin-in-a-task-sources-table.md
[0067]: 0067-park-an-imported-task-on-an-external-list.md
[0068]: 0068-follow-a-change-in-an-issues-state-not-the-state-itself.md
[0069]: 0069-read-github-over-graphql-and-keep-rest-for-project-reads-and-the-issue-move-check.md
[0070]: 0070-share-one-issue-sync-across-providers-and-run-each-provider-as-its-own-job.md
[0071]: 0071-load-a-tasks-read-and-edit-pages-into-dialogs-with-fetch.md
[0072]: 0072-render-raw-html-in-task-notes-through-the-sanitize-gem.md
[0073]: 0073-read-the-app-version-from-the-git-tag-at-boot.md
[0074]: 0074-split-tags-into-a-public-and-a-private-scope.md
[0075]: 0075-keep-local-and-synced-task-comments-in-one-table-keyed-by-remote-id.md
[0076]: 0076-page-flat-lists-by-number-and-day-grouped-lists-by-whole-day.md
[0077]: 0077-tag-an-imported-task-from-its-labels-only-on-import.md
[0078]: 0078-ignore-a-webmention-through-a-new-status-that-is-neutral-for-trust.md
[0079]: 0079-store-a-mention-as-a-token-expanded-at-delivery.md
[0080]: 0080-store-photos-in-an-s3-store-and-serve-them-through-the-site.md
[0081]: 0081-process-every-upload-with-libvips-on-the-server.md
[0082]: 0082-tie-a-photo-to-the-records-whose-markdown-points-to-it.md
[0083]: 0083-upload-photos-by-fetch-from-the-markdown-editor.md
[0084]: 0084-keep-edit-notes-in-a-post-edits-table-and-require-one-under-the-posts-lock.md
[0085]: 0085-reorder-tasks-by-drag-and-save-the-order-through-fetch.md
[0086]: 0086-serve-a-json-api-behind-long-lived-tokens-minted-in-the-admin.md
[0087]: 0087-widen-what-analytics-keeps-with-a-monthly-hash-and-roll-up-each-pages-breakdowns.md
[0088]: 0088-hold-the-layer-the-api-and-mcp-share-in-the-api-slice-and-call-it-in-process.md
[0089]: 0089-build-every-api-response-with-alba-serializers.md
[0090]: 0090-let-cloudflare-keep-anonymous-public-pages-for-five-minutes.md
[0091]: 0091-fetch-the-palettes-open-tasks-from-a-session-only-admin-route-when-it-opens.md
[0092]: 0092-keep-task-history-in-task-events-and-a-task-timeline-view.md
[0093]: 0093-link-any-two-records-through-one-record-links-table-in-a-links-slice.md
[0094]: 0094-keep-a-seen-at-on-task-sources-and-merge-the-inbox-in-the-api-slice.md
[0095]: 0095-build-the-stalled-list-in-the-activity-slice-and-keep-snoozes-in-attention-snoozes.md
[0096]: 0096-search-every-kind-through-tsvector-columns-and-one-view-in-a-search-slice.md
[0097]: 0097-keep-saved-views-in-their-own-slice-with-a-screen-enum-and-jsonb-filters.md
[0098]: 0098-run-each-bulk-action-as-one-operation-per-list-in-one-transaction.md
[0099]: 0099-keep-decision-logs-in-a-decisions-slice-with-decision-events-and-a-decision-timeline-view.md
[0100]: 0100-build-the-review-in-one-activity-query-that-admin-and-api-share.md
[0101]: 0101-bind-every-admin-key-through-one-key-map-that-reads-keys-from-the-markup.md
[0102]: 0102-count-each-posts-unique-readers-with-an-undated-hash-kept-for-12-months.md
[0103]: 0103-tag-an-imported-task-from-repo-rules-on-import-and-once-on-create.md
[0104]: 0104-version-releases-with-calver-back-to-the-first-release.md
[0105]: 0105-dump-the-database-nightly-to-a-private-backups-bucket-and-keep-the-newest-7.md
[0106]: 0106-count-feed-fetches-on-the-server-and-capture-outbound-clicks-from-the-beacon.md
[0107]: 0107-trust-a-webmention-author-only-under-their-url-and-a-whole-host-only-when-marked.md
[0108]: 0108-show-remote-images-in-imported-markdown-as-links.md
[0109]: 0109-let-cloudflare-keep-a-published-photo-for-one-day.md
[0110]: 0110-take-subscriber-counts-only-from-the-feed-aggregators-we-name.md
[0111]: 0111-send-strict-transport-security-from-the-app-for-the-apex-alone.md
[0112]: 0112-give-every-tag-rule-a-provider-and-match-linear-issues-by-workspace-and-team.md
[active]: https://img.shields.io/badge/Active-green?style=for-the-badge
[superseded-0069]: https://img.shields.io/badge/0069-black?style=for-the-badge&label=Superseded&labelColor=orange
[superseded-0096]: https://img.shields.io/badge/0096-black?style=for-the-badge&label=Superseded&labelColor=orange
[superseded-0102]: https://img.shields.io/badge/0102-black?style=for-the-badge&label=Superseded&labelColor=orange
[superseded-0107]: https://img.shields.io/badge/0107-black?style=for-the-badge&label=Superseded&labelColor=orange
[superseded-0110]: https://img.shields.io/badge/0110-black?style=for-the-badge&label=Superseded&labelColor=orange
[writing ADRs]: ../writing-adrs.md
